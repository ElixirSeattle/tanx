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
      :ok = GenServer.call(arena_view, {:update, {[], []}})
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
    state = check_responses(%State{state | received: received, expected: expected})
    final_reply(state)
  end

  def handle_cast({:object_died, object}, state) do
    expected = state.expected |> Set.delete(object)
    state = check_responses(%State{state | expected: expected})
    final_reply(state)
  end


  defp final_reply(state = %State{expected: nil}) do
    {:stop, :normal, state}
  end
  defp final_reply(state) do
    {:noreply, state}
  end


  defp check_responses(state) do
    if Enum.empty?(state.expected) do
      process_responses(state)
    else
      state
    end
  end


  defp process_responses(state) do
    categorized_responses = state.received
      |> Enum.group_by(fn
        %Tanx.Core.Updates.MoveTank{} -> :tank
        %Tanx.Core.Updates.MoveMissile{} -> :missile
        _ -> :unknown
      end)
    tank_responses = Dict.get(categorized_responses, :tank, [])
    missile_responses = Dict.get(categorized_responses, :missile, [])

    tank_responses = resolve_tank_forces(tank_responses)

    # TODO: Tank-missile collisions

    send_revised_tanks(tank_responses)
    tank_views = create_tank_views(state, tank_responses)
    missile_views = create_missile_views(missile_responses)

    :ok = GenServer.call(state.arena_view, {:update, {tank_views, missile_views}})

    GenServer.cast(state.clock, :clock_tock)
    %State{state | expected: nil, received: nil}
  end


  defp resolve_tank_forces(tank_responses) do
    radius = Tanx.Core.Tank.collision_radius() * 2
    tank_responses |> Enum.map(fn tank1 ->
      player1 = tank1.player
      pos1 = tank1.pos
      tank1 = tank_responses |> Enum.reduce(tank1, fn (tank2, cur_tank1) ->
        if tank2.player == player1 do
          cur_tank1
        else
          {fx, fy} = force = Tanx.Core.Obstacles.force_from_point(tank2.pos, pos1, radius)
          if fx == 0 and fy == 0 do
            cur_tank1
          else
            %Tanx.Core.Updates.MoveTank{cur_tank1 | force: vadd(cur_tank1.force, force)}
          end
        end
      end)
      new_pos = vadd(tank1.pos, tank1.force)
      %Tanx.Core.Updates.MoveTank{tank1 | pos: new_pos}
    end)
  end


  defp send_revised_tanks(responses) do
    responses |> Enum.each(fn
      tank ->
        {newx, newy} = tank.pos
        GenServer.cast(tank.tank, {:moveto, newx, newy})
    end)
  end


  defp create_tank_views(state, responses) do
    responses |> Enum.flat_map(fn response ->
      player_view = GenServer.call(state.player_manager, {:view_player, response.player})
      if player_view do
        {x, y} = response.pos
        tank = %Tanx.Core.ArenaView.TankInfo{player: response.player, name: player_view.name,
          x: x, y: y, heading: response.heading, radius: response.radius}
        [tank]
      else
        []
      end
    end)
  end


  defp create_missile_views(responses) do
    responses |> Enum.map(fn response ->
      %Tanx.Core.ArenaView.MissileInfo{player: response.player,
        x: response.x, y: response.y, heading: response.heading}
    end)
  end


  defp vadd({x0, y0}, {x1, y1}), do: {x0 + x1, y0 + y1}

end
