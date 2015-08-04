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


  require Logger


  #### API internal to Tanx.Core


  @doc """
    Starts an ArenaUpdater process. This should be called only from a Game process.
  """
  def start(entry_points, arena_objects, arena_view, player_manager, clock, last_time, time) do
    GenServer.start(__MODULE__,
        {entry_points, arena_objects, arena_view, player_manager, clock, last_time, time})
  end


  @doc """
    Sends a reply to an update message received from this updater.
    This should be called once from an arena object that receives an update request.
  """
  def send_update_reply(arena_updater, update) do
    :ok = GenServer.cast(arena_updater, {:update_reply, self, update})
  end


  @doc """
    Notifies the given updater that the given arena object died and should be forgotten.
  """
  def forget_object(arena_updater, object) do
    :ok = GenServer.cast(arena_updater, {:object_died, object})
  end


  #### GenServer callbacks

  use GenServer


  defmodule State do
    defstruct entry_points: [],
              arena_objects: nil,
              arena_view: nil,
              player_manager: nil,
              clock: nil,
              expected: nil,
              received: nil
  end


  def init({entry_points, arena_objects, arena_view, player_manager, clock, last_time, time}) do
    objects = arena_objects |> Tanx.Core.ArenaObjects.get_objects
    if Enum.empty?(objects) do
      :ok = arena_view |> Tanx.Core.ArenaView.clear_objects
      entry_point_availability = create_entry_point_availability([], entry_points)
      arena_objects |> Tanx.Core.ArenaObjects.update_entry_point_availability(entry_point_availability)
      clock |> Tanx.Core.Clock.send_tock
      :ignore
    else
      objects |> Enum.each(&(GenServer.cast(&1, {:update, last_time, time, self})))
      expected = objects |> Enum.into(HashSet.new)
      state = %State{
        entry_points: entry_points,
        arena_objects: arena_objects,
        arena_view: arena_view,
        player_manager: player_manager,
        clock: clock,
        expected: expected,
        received: []
      }
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
        %Tanx.Core.Updates.Explosion{} -> :explosion
        _ -> :unknown
      end)
    tank_responses = Dict.get(categorized_responses, :tank, [])
    missile_responses = Dict.get(categorized_responses, :missile, [])
    explosion_responses = Dict.get(categorized_responses, :explosion, [])

    tank_responses = resolve_tank_forces(tank_responses)

    detect_tank_missile_collision(tank_responses, missile_responses)

    send_revised_tanks(tank_responses)

    entry_point_availability = create_entry_point_availability(tank_responses, state.entry_points)
    tank_views = create_tank_views(state, tank_responses)
    missile_views = create_missile_views(missile_responses)
    explosion_views = create_explosion_views(explosion_responses)

    state.arena_objects |> Tanx.Core.ArenaObjects.update_entry_point_availability(entry_point_availability)

    :ok = state.arena_view |> Tanx.Core.ArenaView.set_objects(
        tank_views, missile_views, explosion_views, entry_point_availability)

    state.clock |> Tanx.Core.Clock.send_tock
    %State{state | expected: nil, received: nil}
  end

  defp detect_tank_missile_collision(tank_responses, missile_responses) do
    for missile <- missile_responses,
        collide_with_tank?(missile, tank_responses) do
      Tanx.Core.Missile.explode(missile.missile)
    end
  end


  defp collide_with_tank?(missile, tanks) do
    tank_to_destroy =
      tanks |> Enum.find(fn(%Tanx.Core.Updates.MoveTank{pos: {tank_x, tank_y}} = tank) ->
                          if missile.player != tank.player, do:
                            same_position?({missile.x, missile.y}, {tank_x, tank_y}, tank.radius)
                        end)

    if tank_to_destroy != nil do
      Tanx.Core.Player.remove_tank(tank_to_destroy.player)
      Tanx.Core.Player.inc_kills(missile.player)
      true
    else
      false
    end
  end

  defp same_position?({x1, y1}, {x2, y2}, radius) do
      x1 <= x2 + radius and
      x1 >= x2 - radius and
      y1 <= y2 + radius and
      y1 >= y2 - radius
  end

  defp create_entry_point_availability(tank_responses, entry_points) do
    entry_points
      |> Enum.reduce(%{}, fn (ep, dict) ->
        is_available = tank_responses
          |> Enum.all?(fn tank ->
            {tank_x, tank_y} = tank.pos
            tank_x < ep.x - ep.buffer_left or
              tank_x > ep.x + ep.buffer_right or
              tank_y < ep.y - ep.buffer_down or
              tank_y > ep.y + ep.buffer_up
          end)
        dict |> Dict.put(ep.name, is_available)
      end)
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
        GenServer.cast(tank.tank, {:move_to, newx, newy})
    end)
  end

  defp create_tank_views(state, responses) do
    responses |> Enum.flat_map(fn response ->
      player_view = state.player_manager |> Tanx.Core.PlayerManager.view_player(response.player)
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

  defp create_explosion_views(responses) do
    responses |> Enum.map(fn response ->
      {x, y} = response.pos
      %Tanx.Core.View.Explosion{x: x, y: y, radius: response.radius, age: response.age}
    end)
  end

  defp vadd({x0, y0}, {x1, y1}), do: {x0 + x1, y0 + y1}

end
