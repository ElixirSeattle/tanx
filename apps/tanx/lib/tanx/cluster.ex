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

  def connect_node(node) do
    Horde.Cluster.join_hordes(Tanx.HordeHandoff, {Tanx.HordeHandoff, node})
    Horde.Cluster.join_hordes(Tanx.HordeSupervisor, {Tanx.HordeSupervisor, node})
    Horde.Cluster.join_hordes(Tanx.HordeRegistry, {Tanx.HordeRegistry, node})
  end

  def start_game(game_spec, opts \\ []) do
    GenServer.call(Tanx.Cluster.Node, {:start_game, game_spec, opts})
  end

  def stop_game(game_id) do
    GenServer.call(Tanx.Cluster.Node, {:stop_game, game_id})
  end

  def list_game_ids() do
    Map.keys(Horde.Registry.processes(Tanx.HordeRegistry))
  end

  def list_games() do
    list_game_ids()
    |> Enum.map(fn game_id ->
      game_id
      |> game_process()
      |> GenServer.call({:meta})
      |> case do
        {:ok, meta} -> meta
        {:error, _} -> nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  def list_nodes() do
    {:ok, members} = Horde.Cluster.members(Tanx.HordeSupervisor)
    members |> Map.keys() |> Enum.sort()
  end

  def game_process(game_id), do: {:via, Horde.Registry, {Tanx.HordeRegistry, game_id}}

  def add_callback(callback) do
    GenServer.call(Tanx.Cluster.Node, {:add_callback, callback})
  end

  defp start_supervisor() do
    children = [
      {Tanx.Util.Handoff, name: Tanx.HordeHandoff},
      {Horde.Supervisor, name: Tanx.HordeSupervisor, strategy: :one_for_one, children: []},
      {Horde.Registry, name: Tanx.HordeRegistry},
      {Tanx.Cluster.Node, []}
    ]
    {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one, name: Tanx.Cluster.Supervisor)
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

  defmodule Node do
    @interval_millis 1000

    require Logger

    def start_link({}) do
      GenServer.start_link(__MODULE__, {}, name: __MODULE__)
    end

    use GenServer

    defmodule State do
      defstruct(
        nodes: [],
        callbacks: []
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
      Process.send_after(self(), :check_changes, @interval_millis)
      {:ok, %State{}}
    end

    def handle_call({:add_callback, callback}, _from, state) do
      {:reply, :ok, %State{state | callbacks: [callback | state.callbacks]}}
    end

    def handle_call({:start_game, game_spec, opts}, _from, state) do
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

      {:reply, {:ok, game_id, game_pid}, state}
    end

    def handle_call({:stop_game, game_id}, _from, state) do
      Tanx.Game.down(Tanx.Cluster.game_process(game_id))
      Horde.Supervisor.terminate_child(Tanx.HordeSupervisor, Tanx.Game.supervisor_process_id(game_id))

      {:reply, :ok, state}
    end

    def handle_info(:check_changes, state) do
      state = check_node_changes(state)
      Process.send_after(self(), :check_changes, @interval_millis)
      {:noreply, state}
    end

    def handle_info(request, state) do
      Logger.warn("Unexpected message: #{inspect(request)}")
      {:noreply, state}
    end

    def terminate(reason, _state) do
      Logger.info("**** Terminating Cluster due to #{inspect(reason)}")
      # TODO
      :ok
    end

    defp check_node_changes(state) do
      # TODO: Eliminate this polling in favor of pushing changes from handoff
      nodes = Tanx.Cluster.list_nodes()

      if nodes == state.nodes do
        state
      else
        Enum.each(state.callbacks, fn callback ->
          callback.(nodes)
        end)

        %State{state | nodes: nodes}
      end
    end
  end
end
