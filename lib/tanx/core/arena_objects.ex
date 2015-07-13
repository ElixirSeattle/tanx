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
    defstruct updater: nil, objects: HashDict.new
  end


  def init(_) do
    Process.flag(:trap_exit, true)
    {:ok, %State{}}
  end


  # Create a new tank process. This must be called from the player that will own the tank.
  def handle_call({:create_tank, params}, {from, _}, state) do
    {:ok, tank} = GenServer.start_link(Tanx.Core.Tank, {from, params})
    {:reply, tank, %State{state | objects: state.objects |> Dict.put(tank, from)}}
  end


  # TODO: create_missile
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
