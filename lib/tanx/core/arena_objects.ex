defmodule Tanx.Core.ArenaObjects do

  @moduledoc """
  The ArenaObjects is an internal process that keeps track of processes that manage objects
  in the arena. It handles process creation, and responds to requests from the ArenaUpdater to
  get the current list. It also deals with process exiting, and makes sure any running updater
  is kept informed.

  This is not part of the Tanx.Core interface. Hence there are no public API functions in
  this module.
  """


  # GenServer callbacks

  use GenServer


  # The objects field is a map from process ID to owning player.
  defmodule State do
    @moduledoc """
      This struct holds all the objects in the arena.
      updater - this is the PID of the ArenaUpdater process.
      objects - this is a Dict with the keys being the PIDs of the objects and
                the values being pid of the the Player process it belongs to.
    """
    defstruct structure: nil,
              updater: nil,
              objects: HashDict.new,
              decomposed_walls: []
  end


  def init({structure}) do
    Process.flag(:trap_exit, true)
    decomposed_walls = structure.walls
      |> Enum.map(&Tanx.Core.Obstacles.decompose_wall/1)
    {:ok, %State{structure: structure, decomposed_walls: decomposed_walls}}
  end


  # Create a new tank process. This must be called from the player that will own the tank.
  # This is called by the 'player' process.
  def handle_call({:create_tank, params}, {from, _}, state) do
    {:ok, tank} = GenServer.start_link(Tanx.Core.Tank,
      {state.structure.width, state.structure.height, state.decomposed_walls, from, params})
    {:reply, tank, %State{state | objects: state.objects |> Dict.put(tank, from)}}
  end


  # Create a new missile process. This must be called from the player that fired the missile.
  def handle_call({:create_missile, params}, {player, _}, state) do
    {:ok, missile}  = Tanx.Core.Missile.start_link(player, params)
    {:reply, missile, %State{state | objects: state.objects |> Dict.put(missile, player)}}
  end

  # TODO: create_explosion


  # Get a snapshot of the current list of objects. This is called from an updater as the
  # first step in its update process.
  def handle_call(:get, {from, _}, state) do
    {:reply, state.objects |> Dict.keys(), %State{state | updater: from}}
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


  # Trap EXIT to handle the death of object processes. If an object dies, remove it and
  # ensure that any running updater knows not to wait for updates from it.
  def handle_info({:EXIT, pid, _}, state) do
    if state.updater do
      GenServer.cast(state.updater, {:object_died, pid})
    end
    {:noreply, %State{state | objects: state.objects |> Dict.delete(pid)}}
  end
  def handle_info(request, state), do: super(request, state)

end
