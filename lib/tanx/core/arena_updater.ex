defmodule Tanx.Core.ArenaUpdater do

  @moduledoc """
  The ArenaUpdater is an internal process that manages the process of updating the arena.
  A new ArenaUpdater is spawned at each clock tick, and it computes one "frame" of the game
  state.

  This process unfolds as follows:

  1. It calls ArenaObjects to get an up-to-date list of the live objects in the arena.
  2. It sends an :update message to each object process. All arena objects must understand
     this message.
  3. It waits for :update_reply responses from all the objects. A reply is expected from
     every object that was sent an :update. If an object dies before it can send a response,
     ArenaObjects is expected to send an :object_died to this updater to inform it not to
     expect a response from that object.
  4. It processes the responses by building a list of ArenaView info objects with the new
     states (e.g. positions)
  5. It runs a global collision detection to determine what objects have collided and what
     needs to be done about it.
  6. It sends back further commands to objects if necessary to adjust their states based on
     collision detection results. For example, a tank position may need to be altered so
     it doesn't intersect a wall.
  7. It sends the final arena view state to the ArenaView.
  8. It response with a tock message to the clock to inform it that updating is complete.

  This is not part of the Tanx.Core interface. Hence there are no public API functions in
  this module. The Game module will spawn this process at the appropriate time.
  """


  # GenServer callbacks

  use GenServer

  defmodule State do
    defstruct structure: nil, arena_view: nil, player_manager: nil, clock: nil,
      expected: nil, received: nil
  end


  def init({structure, arena_objects, arena_view, player_manager, clock, last_time, time}) do
    objects = GenServer.call(arena_objects, :get)
    if Enum.empty?(objects) do
      :ok = GenServer.call(arena_view, {:update, []})
      GenServer.cast(clock, :clock_tock)
      :ignore
    else
      objects |> Enum.each(&(GenServer.cast(&1, {:update, last_time, time, self})))
      expected = objects |> Enum.into(HashSet.new)
      state = %State{structure: structure, arena_view: arena_view, player_manager: player_manager,
        clock: clock, expected: expected, received: []}
      {:ok, state}
    end
  end


  def handle_cast({:update_reply, object, update}, state) do
    received = [update | state.received]
    expected = state.expected |> Set.delete(object)
    state = _check_responses(%State{state | received: received, expected: expected})
    _final_reply(state)
  end

  def handle_cast({:object_died, object}, state) do
    expected = state.expected |> Set.delete(object)
    state = _check_responses(%State{state | expected: expected})
    _final_reply(state)
  end


  defp _final_reply(state = %State{expected: nil}) do
    {:stop, :normal, state}
  end
  defp _final_reply(state) do
    {:noreply, state}
  end

  defp _check_responses(state) do
    if Enum.empty?(state.expected) do
      _process_responses(state)
    else
      state
    end
  end

  defp _process_responses(state) do
    # TODO: Add missiles, explosions, other objects to this tuple
    {_, tanks} = state.received |> Enum.reduce({state, []}, &_process_response/2)

    # TODO: Collision detection

    :ok = GenServer.call(state.arena_view, {:update, tanks})
    GenServer.cast(state.clock, :clock_tock)
    %State{state | expected: nil, received: nil}
  end

  defp _process_response(response = %Tanx.Core.Updates.MoveTank{}, {state, tanks}) do
    player_view = GenServer.call(state.player_manager, {:view_player, response.player})
    if player_view do
      tank = %Tanx.Core.ArenaView.TankInfo{player: response.player, name: player_view.name,
        x: response.x, y: response.y, heading: response.heading, radius: response.radius}
      {state, [tank | tanks]}
    else
      {state, tanks}
    end
  end
  # TODO: Other updates

end
