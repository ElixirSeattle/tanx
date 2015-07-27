defmodule Tanx.Core.Game do

  @moduledoc """
  The Game process forms the main entry point into the game core.
  Using this module you can view the current player list and connect as a new player.
  """

  require Logger


  #### Public API


  @doc """
  Start a new game and return a process reference for it.

  Supported options include:

  - **:structure** A Tanx.Core.Structure representing the arena size, shape, and walls.
  - **:clock_interval** The interval between clock ticks in milliseconds. Defaults to 20.
    Set to nil to disable automatic clock ticks (useful for unit testing).
  """
  def start_link(opts \\ []) do
    Logger.info("Starting game core")
    genserver_opts = []
    if opts |> Keyword.has_key?(:name) do
      genserver_opts = genserver_opts |> Keyword.put(:name, opts[:name])
    end
    GenServer.start_link(__MODULE__, opts, genserver_opts)
  end


  @doc """
  Connect as a player, and return a player reference that can be passed to
  functions in the Tanx.Core.Player module.

  Supported options include:

  - **:name** The player name.
  """
  def connect(game, opts \\ []) do
    GenServer.call(game, {:connect, opts[:name]})
  end


  @doc """
  Returns a view of the connected players, as a list of Tanx.Core.View.Player structs.
  """
  def view_players(game) do
    GenServer.call(game, :view_players)
  end


  @doc """
  Terminates the game and disconnects all players.
  """
  def terminate(game) do
    GenServer.call(game, :terminate)
  end


  @doc """
  Immediately ticks the clock with the given time value, and waits for all updates to
  complete. This is generally used in unit tests.

  See Tanx.Core.Clock.manual_tick() for return values.
  """
  def manual_clock_tick(game, time) do
    GenServer.call(game, :get_clock) |> Tanx.Core.Clock.manual_tick(time)
  end


  #### GenServer callbacks

  use GenServer

  defmodule PlayerInfo do
    defstruct name: "",
              kills: 0,
              deaths: 0
  end

  defmodule State do
    defstruct structure: nil,
              player_manager: nil,
              arena_objects: nil,
              arena_view: nil,
              clock: nil,
              time_config: nil
  end


  def init(opts) do
    structure = Keyword.get(opts, :structure, %Tanx.Core.Structure{})
    clock_interval = Keyword.get(opts, :clock_interval, 20)
    {change_handler, handler_args} = Keyword.get(opts, :player_change_handler, {nil, nil})
    time_config = Keyword.get(opts, :time_config, nil)

    arena_objects = Tanx.Core.ArenaObjects.start_link(structure)
    arena_view = Tanx.Core.ArenaView.start_link(structure)
    player_manager = Tanx.Core.PlayerManager.start_link(
        arena_objects, arena_view, time_config, change_handler, handler_args)
    clock = Tanx.Core.Clock.start_link(self, clock_interval, time_config)

    state = %State{
      structure: structure,
      player_manager: player_manager,
      arena_objects: arena_objects,
      arena_view: arena_view,
      clock: clock,
      time_config: time_config
    }
    {:ok, state}
  end


  def handle_call({:connect, name}, _from, state) do
    response = state.player_manager |> Tanx.Core.PlayerManager.create_player(name)
    {:reply, response, state}
  end


  def handle_call(:view_players, _from, state) do
    views = state.player_manager |> Tanx.Core.PlayerManager.view_all_players
    {:reply, views, state}
  end


  def handle_call(:terminate, _from, state) do
    {:stop, :normal, :ok, state}
  end


  def handle_call(:get_clock, _from, state) do
    {:reply, state.clock, state}
  end


  # Whenever a clock tick is received, we spawn an updater process. That updater performs
  # all the update computation, including getting information from arena object processes
  # such as tanks, and then updates the ArenaView state.
  def handle_cast({:clock_tick, _clock, last_time, time}, state) do
    Tanx.Core.ArenaUpdater.start(
        state.arena_objects, state.arena_view, state.player_manager, state.clock, last_time, time)
    {:noreply, state}
  end

end
