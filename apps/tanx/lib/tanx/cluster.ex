defmodule Tanx.Cluster do
  @connect_env "TANX_CONNECT_NODE"

  require Logger

  def start_link(opts \\ []) do
    sup = start_supervisor()
    connect_initial_nodes(opts)
    {:ok, sup}
  end

  def stop() do
    Supervisor.stop(Tanx.Cluster.Supervisor)
  end

  def connect_node(:""), do: nil

  def connect_node(node) do
    Horde.Cluster.join_hordes(Tanx.HordeHandoff, {Tanx.HordeHandoff, node})
    Horde.Cluster.join_hordes(Tanx.HordeSupervisor, {Tanx.HordeSupervisor, node})
    Horde.Cluster.join_hordes(Tanx.HordeRegistry, {Tanx.HordeRegistry, node})
  end

  def start_game(game_spec, opts \\ []) do
    game_id = Tanx.Util.ID.create("G", Tanx.Cluster.list_game_ids(), 8)

    opts =
      opts
      |> Keyword.put(:handoff, Tanx.HordeHandoff)
      |> Keyword.put(:game_address, Tanx.Cluster.game_process(game_id))

    child_spec = Tanx.Game.child_spec({game_id, opts})
    {:ok, supervisor_pid} = Horde.Supervisor.start_child(Tanx.HordeSupervisor, child_spec)

    manager_id = Tanx.Game.manager_process_id(game_id)

    game_pid =
      supervisor_pid
      |> Supervisor.which_children()
      |> Enum.find_value(fn
        {^manager_id, pid, :worker, _} -> pid
        _ -> false
      end)

    Tanx.Game.up(game_pid, game_spec)

    {:ok, game_id, game_pid}
  end

  def stop_game(game_id) do
    Tanx.Game.down(Tanx.Cluster.game_process(game_id))
    Horde.Registry.unregister(Tanx.HordeRegistry, game_id)

    Horde.Supervisor.terminate_child(
      Tanx.HordeSupervisor,
      Tanx.Game.supervisor_process_id(game_id)
    )

    :ok
  end

  def list_game_ids() do
    Tanx.HordeRegistry
    |> Horde.Registry.processes()
    |> Map.keys()
  end

  def load_game_meta(game_ids) do
    Enum.map(game_ids, fn game_id ->
      try do
        game_id
        |> game_process()
        |> GenServer.call({:meta})
        |> case do
          {:ok, meta} -> meta
          {:error, _} -> nil
        end
      catch
        :exit, {:noproc, _} -> nil
      end
    end)
  end

  def game_alive?(game_id) do
    Horde.Registry.lookup(Tanx.HordeRegistry, game_id) != :undefined
  end

  def list_nodes() do
    {:ok, members} = Horde.Cluster.members(Tanx.HordeSupervisor)
    members |> Map.keys() |> Enum.sort()
  end

  def game_process(game_id), do: {:via, Horde.Registry, {Tanx.HordeRegistry, game_id}}

  def list_live_game_ids() do
    GenServer.call(Tanx.Cluster.Tracker, {:list_live_game_ids})
  end

  def add_receiver(receiver, message) do
    GenServer.call(Tanx.Cluster.Tracker, {:add_receiver, receiver, message})
  end

  defp start_supervisor() do
    children = [
      {Tanx.Util.Handoff, name: Tanx.HordeHandoff},
      {Horde.Supervisor, name: Tanx.HordeSupervisor, strategy: :one_for_one, children: []},
      {Horde.Registry, name: Tanx.HordeRegistry},
      {Tanx.Cluster.Tracker, []}
    ]

    {:ok, sup} =
      Supervisor.start_link(children, strategy: :one_for_one, name: Tanx.Cluster.Supervisor)

    sup
  end

  defp connect_initial_nodes(opts) do
    default_connect = String.split(System.get_env(@connect_env) || "", ",")

    opts
    |> Keyword.get(:connect, default_connect)
    |> Enum.each(fn node ->
      node |> String.to_atom() |> connect_node()
    end)

    :ok
  end

  defmodule Tracker do
    @interval_millis 1000
    @expiration_millis 60000

    require Logger

    def start_link({}) do
      GenServer.start_link(__MODULE__, {}, name: __MODULE__)
    end

    use GenServer

    defmodule State do
      defstruct(
        game_ids: [],
        dead_game_ids: %{},
        receivers: []
      )
    end

    def child_spec(_args) do
      %{
        id: __MODULE__,
        start: {__MODULE__, :start_link, [{}]},
        restart: :transient
      }
    end

    def init({}) do
      Process.send_after(self(), :update_game_ids, @interval_millis)
      {:ok, %State{}}
    end

    def handle_info(:update_game_ids, state) do
      {alive, dead} = Enum.split_with(Tanx.Cluster.list_game_ids(), &Tanx.Cluster.game_alive?/1)
      dgi = update_dead_game_ids(dead, state.dead_game_ids)
      agi = Enum.sort(alive)
      receivers = send_update(state.receivers, agi, state.game_ids)
      Process.send_after(self(), :update_game_ids, @interval_millis)
      {:noreply, %State{state | game_ids: agi, dead_game_ids: dgi, receivers: receivers}}
    end

    def handle_info(request, state) do
      Logger.warn("Unexpected message: #{inspect(request)}")
      {:noreply, state}
    end

    def handle_call({:add_receiver, receiver, message}, _from, state) do
      {:reply, :ok, %State{state | receivers: [{receiver, message} | state.receivers]}}
    end

    def handle_call({:list_live_game_ids}, _from, state) do
      {:reply, state.game_ids, state}
    end

    defp update_dead_game_ids(dead, old_dgi) do
      time = System.monotonic_time(:millisecond)

      Enum.reduce(dead, %{}, fn g, d ->
        if Map.has_key?(old_dgi, g) do
          old_time = old_dgi[g]

          if time - old_time > @expiration_millis do
            Horde.Registry.unregister(Tanx.HordeRegistry, g)
            Logger.warn("**** Unregistered stale game #{inspect(g)}")
            d
          else
            Map.put(d, g, old_time)
          end
        else
          Map.put(d, g, time)
        end
      end)
    end

    defp send_update(receivers, agi, agi), do: receivers

    defp send_update(receivers, agi, _old_agi) do
      Logger.info("**** Sending cluster update #{inspect(agi)}")

      Enum.filter(receivers, fn {receiver, message} ->
        if Process.alive?(receiver) do
          send(receiver, {message, agi})
          true
        else
          false
        end
      end)
    end
  end
end
