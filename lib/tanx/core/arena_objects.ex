defmodule Tanx.Core.ArenaObjects do

  @moduledoc """
  The ArenaObjects is an internal process that keeps track of processes that manage objects
  in the arena. It handles process creation, and responds to requests from the ArenaUpdater to
  get the current list. It also deals with process exiting, and makes sure any running updater
  is kept informed.

  This is not part of the Tanx.Core interface. Hence there are no public API functions in
  this module.
  """


  #### API internal to Tanx.Core


  @doc """
    Starts an ArenaObjects process. This should be called only from a Game process.
  """
  def start_link(structure) do
    {:ok, pid} = GenServer.start_link(__MODULE__, {structure})
    pid
  end


  @doc """
    Create a new tank process. This must be called from the player that will own the tank.

    The keyword list may include the following:

    - **:x** The initial x position.
    - **:y** The initial y position.
    - **:heading** The initial heading in radians (where 0 is to the right).
  """
  def create_tank(arena_objects, params \\ []) do
    GenServer.call(arena_objects, {:create_tank, params})
  end


  @doc """
    Create a new missile process. This must be called from the player that will own the missile.
  """
  def create_missile(arena_objects, x, y, heading) do
    GenServer.call(arena_objects, {:create_missile, x, y, heading})
  end

  @doc """
    Create a new power up. This is call when the tank explodes in a game.
  """
  def create_power_up(arena_objects, {x, y}, type \\ nil) do 
    GenServer.call(arena_objects, {:create_power_up, x, y, type})
  end

  @doc """
    Remove the missile process.
  """
  def explode_missile(arena_objects, missile) do
    GenServer.cast(arena_objects, {:explode_missile, missile})
  end

  @doc """
    Get a list of all live arena objects. This may be called only by an ArenaUpdater.
  """
  def get_objects(arena_objects) do
    GenServer.call(arena_objects, :get_objects)
  end


  @doc """
    Update the entry point availability state. This may be called only by an ArenaUpdater.
  """
  def update_entry_point_availability(arena_objects, availability) do
    GenServer.cast(arena_objects, {:update_entry_point_availability, availability})
  end


  @doc """
    Kill all objects owned by the given player
  """
  def kill_player_objects(arena_objects, player) do
    GenServer.call(arena_objects, {:player_left, player})
  end


  #### GenServer callbacks

  use GenServer


  # The objects field is a map from process ID to owning player.
  defmodule State do
    @moduledoc """
      This struct holds all the objects in the arena.
      updater - this is the PID of the ArenaUpdater process.
      objects - this is a Dict with the keys being the PIDs of the objects and
                the values being pid of the the Player process it belongs to.
    """
    defstruct arena_width: 20.0,
              arena_height: 20.0,
              updater: nil,
              objects: HashDict.new,
              entry_points: HashDict.new,
              decomposed_walls: []
  end

  # Entry point
  defmodule EntryPointInfo do
    # Availability values:
    # - occupied: the view determined that a tank is in the vicinity
    # - clear: the view determined that the entry point is clear, and no one has used it yet
    # - used: someone has used this entry point but the updater doesn't know yet
    # - updating: the updater has been notified of a new tank
    defstruct x: 0.0,
              y: 0.0,
              heading: 0.0,
              avail: :clear
  end


  def init({structure}) do
    Process.flag(:trap_exit, true)
    decomposed_walls = structure.walls
      |> Enum.map(&Tanx.Core.Obstacles.decompose_wall/1)
    entry_points = structure.entry_points
      |> Enum.reduce(HashDict.new, fn (ep, dict) ->
        dict |> Dict.put(ep.name, %EntryPointInfo{x: ep.x, y: ep.y, heading: ep.heading})
      end)

    state = %State{
      arena_width: structure.width,
      arena_height: structure.height,
      decomposed_walls: decomposed_walls,
      entry_points: entry_points
    }
    {:ok, state}
  end


  # Create a new tank process. This must be called from the player that will own the tank.
  # This is called by the 'player' process.
  def handle_call({:create_tank, params}, {from, _}, state) do
    case interpret_entry_point(params, state) do
      {nil, state} ->
        {:reply, {:error, :entry_point_occupied}, state}
      {params, state} ->
        tank = Tanx.Core.Tank.start_link(
            state.arena_width, state.arena_height, state.decomposed_walls, from, params)
        state = %State{state | objects: state.objects |> Dict.put(tank, from)}
        {:reply, {:ok, tank}, state}
    end
  end


  # Create a new missile process. This must be called from the player that fired the missile.
  def handle_call({:create_missile, x, y, heading}, {player, _}, state) do
    {:ok, missile}  = Tanx.Core.Missile.start_link(player,
                                                   state.arena_width,
                                                   state.arena_height,
                                                   state.decomposed_walls, 
                                                   x, 
                                                   y, 
                                                   heading)
    {:reply, missile, %State{state | objects: state.objects |> Dict.put(missile, player)}}
  end

  def handle_call({:create_power_up, x, y, type}, _, state) do 
    {:ok, power_up} = Tanx.Core.PowerUp.start_link(x, y, type)
    {:reply, power_up, %State{state | objects: state.objects |> Dict.put(power_up, nil)}}
  end

  # Get a snapshot of the current list of objects. This is called from an updater as the
  # first step in its update process.
  def handle_call(:get_objects, {from, _}, state) do
    entry_points = state.entry_points
      |> Enum.map(fn
        {name, ep = %EntryPointInfo{avail: :used}} -> {name, %EntryPointInfo{ep | avail: :updating}}
        entry -> entry
      end)
      |> Enum.into(HashDict.new)

    {:reply, state.objects |> Dict.keys(), %State{state | updater: from, entry_points: entry_points}}
  end


  # If a player leaves, kill any objects (such as tanks) owned by that player.
  def handle_call({:player_left, player}, _from, state) do
    objects = state.objects
      |> Dict.to_list()
      |> Enum.filter(&(elem(&1, 1) == player))
      |> Enum.reduce(state.objects, fn ({object, _player}, objects) ->
        GenServer.cast(object, :die)
        objects |> Dict.delete(object)
      end)
    {:reply, :ok, %State{state | objects: objects}}
  end

  def handle_cast({:explode_missile, missile}, state) do
    state = %State{state | objects: Dict.delete(state.objects, missile)}
    {:noreply, state}
  end
  
  def handle_cast({:update_entry_point_availability, availability}, state) do
    entry_points = availability
      |> Enum.reduce(state.entry_points, fn {name, available}, eps ->
        ep = eps[name]
        if ep == nil do
          eps
        else
          if available do
            if ep.avail != :used do
              eps |> Dict.put(name, %EntryPointInfo{ep | avail: :clear})
            else
              eps
            end
          else
            eps |> Dict.put(name, %EntryPointInfo{ep | avail: :occupied})
          end
        end
      end)
    state = %State{state | entry_points: entry_points}
    {:noreply, state}
  end


  # Trap EXIT to handle the death of object processes. If an object dies, remove it and
  # ensure that any running updater knows not to wait for updates from it.
  def handle_info({:EXIT, pid, _}, state) do
    if state.updater do
      state.updater |> Tanx.Core.ArenaUpdater.forget_object(pid)
    end
    {:noreply, %State{state | objects: state.objects |> Dict.delete(pid)}}
  end
  def handle_info(request, state), do: super(request, state)


  defp interpret_entry_point(params, state) do
    entry_point_name = params |> Keyword.get(:entry_point, nil)
    entry_point = state.entry_points |> Dict.get(entry_point_name, nil)
    if entry_point == nil do
      {params, state}
    else
      if entry_point.avail == :clear do
        params = params
          |> Keyword.put(:x, entry_point.x)
          |> Keyword.put(:y, entry_point.y)
          |> Keyword.put(:heading, entry_point.heading)
        entry_point = %EntryPointInfo{entry_point | avail: :used}
        entry_points = state.entry_points |> Dict.put(entry_point_name, entry_point)
        state = %State{state | entry_points: entry_points}
        {params, state}
      else
        {nil, state}
      end
    end
  end

end
