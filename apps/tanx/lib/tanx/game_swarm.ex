defmodule Tanx.GameSwarm do
  @games_group :games
  @nodes_group :nodes
  @connect_env "TANX_CONNECT_NODE"
  @interval_millis 1000

  require Logger

  def start_link(opts \\ []) do
    connect = String.split(System.get_env(@connect_env) || "", ",")
    connect = Keyword.get(opts, :connect, connect)

    Enum.each(connect, fn node ->
      node |> String.to_atom() |> Node.connect()
    end)

    {:ok, pid} = GenServer.start_link(__MODULE__, {}, name: __MODULE__)
    :yes = Swarm.register_name("N:#{Node.self()}", pid)
    Swarm.join(@nodes_group, pid)
    {:ok, pid}
  end

  def start_game(game_spec, opts \\ []) do
    registered = Swarm.registered() |> Enum.map(fn {id, _pid} -> id end)
    game_id = Tanx.Util.ID.create("G", registered, 8)
    opts_with_game_id = Keyword.put(opts, :game_id, game_id)

    case Swarm.register_name(game_id, Tanx.Game, :create, [opts_with_game_id]) do
      {:error, {:already_registered, _pid}} ->
        start_game(game_spec, opts)

      {:error, other_reason} ->
        {:error, other_reason}

      {:ok, pid} ->
        Tanx.Game.startup(pid, game_spec)
        Swarm.join(@games_group, pid)
        {:ok, game_id}
    end
  end

  def list_games() do
    @games_group
    |> Swarm.multi_call({:meta}, 1000)
    |> Enum.map(fn
      {:ok, meta} -> meta
      {:error, _} -> nil
    end)
    |> Enum.filter(&(&1 != nil))
  end

  def list_nodes() do
    Swarm.members(@nodes_group) |> Enum.sort()
  end

  def game_process(game_id), do: {:via, :swarm, game_id}

  def add_callback(callback) do
    GenServer.call(__MODULE__, {:add_callback, callback})
  end

  def kick_games() do
    Logger.info("**** Kicking all games from #{Node.self()}")
    Swarm.multi_call(@games_group, {:start_handoff, Node.self()})
  end

  #### GenServer callbacks

  use GenServer

  defmodule State do
    defstruct(
      nodes: [],
      callbacks: []
    )
  end

  def child_spec(opts \\ []) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient
    }
  end

  def init({}) do
    Process.flag(:trap_exit, true)
    Process.send_after(self(), :check_changes, @interval_millis)
    {:ok, %State{}}
  end

  def handle_call({:add_callback, callback}, _from, state) do
    {:reply, :ok, %State{state | callbacks: [callback | state.callbacks]}}
  end

  def handle_info(:check_changes, state) do
    state = check_node_changes(state)
    Process.send_after(self(), :check_changes, @interval_millis)
    {:noreply, state}
  end

  def handle_info(request, state), do: super(request, state)

  def terminate(reason, _state) do
    Logger.info("**** Terminating GameSwarm due to #{inspect(reason)}")
    kick_games()
    :ok
  end

  defp check_node_changes(state) do
    nodes = list_nodes()

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
