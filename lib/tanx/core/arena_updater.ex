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


  defmodule DestroyTank do
    defstruct tank: nil,
              dead_player: nil,
              culprit_player: nil,
              final_pos: nil
  end


  defmodule DestroyMissile do
    defstruct missile: nil
  end

  defmodule DestroyPowerUp do
    defstruct powerup: nil,
              collected_by: nil,
              type: nil
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
        %Tanx.Core.Updates.PowerUp{} -> :power_up
        _ -> :unknown
      end)

    tank_responses = Dict.get(categorized_responses, :tank, [])
    missile_responses = Dict.get(categorized_responses, :missile, [])
    explosion_responses = Dict.get(categorized_responses, :explosion, [])
    powerup_responses = Dict.get(categorized_responses, :power_up, [])

    {tank_responses, powerup_responses} = resolve_tank_powerup_collisions(tank_responses, powerup_responses)
    tank_responses = resolve_tank_forces(tank_responses)
    {missile_responses, tank_responses} = resolve_tank_missile_collisions(missile_responses, tank_responses)
    tank_responses = resolve_chain_reactions(explosion_responses, tank_responses)

    send_revisions(state.arena_objects, state.player_manager, tank_responses, missile_responses, powerup_responses)

    entry_point_availability = create_entry_point_availability(tank_responses, state.entry_points)
    tank_views = create_tank_views(state, tank_responses)
    missile_views = create_missile_views(missile_responses)
    explosion_views = create_explosion_views(explosion_responses)
    powerup_views = create_powerup_views(powerup_responses)

    state.arena_objects |> Tanx.Core.ArenaObjects.update_entry_point_availability(entry_point_availability)

    :ok = state.arena_view |> Tanx.Core.ArenaView.set_objects(
        tank_views, missile_views, explosion_views, powerup_views, entry_point_availability)

    state.clock |> Tanx.Core.Clock.send_tock
    %State{state | expected: nil, received: nil}
  end

  defp resolve_tank_powerup_collisions(tank_responses, powerup_responses) do
   # Kernel.inspect tank_responses
    tank_radius = Tanx.Core.Tank.collision_radius
    tank_responses |> Enum.map_reduce(powerup_responses, fn(cur_tank, cur_powerups) ->
         {next_powerups, next_tank} = cur_powerups |> Enum.map_reduce(cur_tank, fn
          (powerup = %DestroyPowerUp{}, cur_tank) ->
            {powerup, cur_tank}
          (powerup, cur_tank) ->
            collision = powerup_hit(powerup.pos, powerup.radius, cur_tank.pos, tank_radius)
            if collision == true do
              powerup = %DestroyPowerUp{powerup: powerup.powerup,
                                        collected_by: cur_tank.player,
                                        type: powerup.type}
            end
            {powerup, cur_tank}
          end)
          {next_tank, next_powerups}
      end)
  end

  defp powerup_hit({px, py}, pr, {tx, ty}, tr) do
    (px - tx) * (px - tx) + (py - ty) * (py - ty) <= ((pr + tr) * (pr + tr))/2
  end

  defp resolve_tank_missile_collisions(missile_responses, tank_responses) do
    tank_radius = Tanx.Core.Tank.collision_radius
    missile_responses |> Enum.map_reduce(tank_responses, fn
      (cur_missile, cur_tanks) ->
        {next_tanks, next_missile} = cur_tanks |> Enum.map_reduce(cur_missile, fn
          (tank, missile = %DestroyMissile{}) ->
            {tank, missile}
          (tank = %DestroyTank{} , missile) ->
            {tank, missile}
          (tank, missile) ->
              hit = missile_hit(missile.pos, missile.heading, tank.pos, tank_radius, missile.strength)
            if hit > 0.0 do
              armor = tank.armor - hit
              if armor <= 0.0 do
                tank = %DestroyTank{tank: tank.tank, dead_player: tank.player, culprit_player: missile.player, final_pos: tank.pos}
              else
                tank = %Tanx.Core.Updates.MoveTank{tank | armor: armor}
              end
              {tank, %DestroyMissile{missile: missile.missile}}
            else
              {tank, missile}
            end
          end)
        {next_missile, next_tanks}
      end)
  end


  defp missile_hit({mx, my}, {mhx, mhy}, {tx, ty}, radius, strength) do
    bx = tx - mx
    by = ty - my
    if bx * bx + by * by <= radius * radius do
      hypotenuse = :math.sqrt(mhx * mhx + mhy * mhy)
      vx = mhx / hypotenuse
      vy = mhy / hypotenuse

      dot = vx * bx + vy * by
      cx = mx + dot * vx
      cy = my + dot * vy
      dist = :math.sqrt((tx - cx) * (tx - cx) + (ty - cy) * (ty - cy))
      (1.0 - dist / radius) * strength
    else
      0.0
    end
  end


  defp resolve_chain_reactions(explosion_responses, tank_responses) do
    tank_radius = Tanx.Core.Tank.chain_radius
    explosion_responses |> Enum.reduce(tank_responses, fn
      (%Tanx.Core.Updates.Explosion{chain_radius: nil}, cur_tanks) ->
        cur_tanks
      (explosion, cur_tanks) ->
        chain_radius = explosion.chain_radius + tank_radius
        cur_tanks |> Enum.map(fn
          tank = %Tanx.Core.Updates.MoveTank{} ->
            hit = explosion_hit(explosion.pos, tank.pos, chain_radius, explosion.intensity)
            if hit > 0.0 do
              armor = tank.armor - hit
              if armor <= 0.0 do
                %DestroyTank{tank: tank.tank, dead_player: tank.player, culprit_player: explosion.originator, final_pos: tank.pos}
              else
                %Tanx.Core.Updates.MoveTank{tank | armor: armor}
              end
            else
              tank
            end
          tank -> tank
        end)
    end)
  end


  defp explosion_hit({x1, y1}, {x2, y2}, radius, intensity) do
    dist = :math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2))
    (1.0 - dist / radius) * intensity
  end


  defp create_entry_point_availability(tank_responses, entry_points) do
    entry_points
      |> Enum.reduce(%{}, fn (ep, dict) ->
        is_available = tank_responses
          |> Enum.all?(fn
            %Tanx.Core.Updates.MoveTank{pos: {tank_x, tank_y}} ->
              tank_x < ep.x - ep.buffer_left or
                tank_x > ep.x + ep.buffer_right or
                tank_y < ep.y - ep.buffer_down or
                tank_y > ep.y + ep.buffer_up
            _ -> true
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


  defp send_revisions(arena_objects, player_manager, tank_responses, missile_responses, powerup_responses) do
    tank_responses |> Enum.each(fn
      %Tanx.Core.Updates.MoveTank{tank: tank, pos: {newx, newy}, armor: armor} ->
        tank |> Tanx.Core.Tank.adjust(newx, newy, armor)
      %DestroyTank{tank: tank, dead_player: dead_player, culprit_player: culprit_player, final_pos: pos} ->
        tank |> Tanx.Core.Tank.destroy(culprit_player)
        player_manager |> Tanx.Core.PlayerManager.inc_deaths(dead_player)
        if culprit_player != dead_player do
          player_manager |> Tanx.Core.PlayerManager.inc_kills(culprit_player)
        end

        Tanx.Core.ArenaObjects.create_power_up(arena_objects, pos)
      end)

    missile_responses |> Enum.each(fn
      %DestroyMissile{missile: missile} ->
        missile |> Tanx.Core.Missile.explode
      _ -> nil
      end)

    powerup_responses |> Enum.each(fn
      %DestroyPowerUp{powerup: powerup, collected_by: player, type: type} ->
        powerup |> Tanx.Core.PowerUp.collect
        player |> Tanx.Core.Player.addPowerUp(type)
      _ -> nil
      end)
  end


  defp create_tank_views(state, responses) do
    responses |> Enum.flat_map(fn
      response = %Tanx.Core.Updates.MoveTank{} ->
        player_view = state.player_manager |> Tanx.Core.PlayerManager.view_player(response.player)
        if player_view do
          {x, y} = response.pos
          tank = %Tanx.Core.ArenaView.TankInfo{
            player: response.player,
            name: player_view.name,
            x: x,
            y: y,
            heading: response.heading,
            radius: response.radius,
            armor: response.armor,
            max_armor: response.max_armor,
            tread: response.tread
          }
          [tank]
        else
          []
        end
      _ -> []
    end)
  end


  defp create_missile_views(responses) do
    responses |> Enum.flat_map(fn
      response = %Tanx.Core.Updates.MoveMissile{} ->
        {x, y} = response.pos
        {hx, hy} = response.heading
        missile = %Tanx.Core.ArenaView.MissileInfo{
          player: response.player,
          x: x,
          y: y,
          hx: hx,
          hy: hy
        }
        [missile]
      _ -> []
    end)
  end


  defp create_explosion_views(responses) do
    responses |> Enum.map(fn response ->
      {x, y} = response.pos
      sound = if response.starting, do: response.intensity, else: nil
      %Tanx.Core.View.Explosion{
        x: x,
        y: y,
        radius: response.radius,
        age: response.age,
        sound: sound
      }
    end)
  end

  defp create_powerup_views(responses) do
    responses |> Enum.flat_map(fn response = %Tanx.Core.Updates.PowerUp{}  ->
                           {x,y} = response.pos
                           powerup = %Tanx.Core.View.PowerUp{x: x, y: y, radius: response.radius, type: response.type}
                          [powerup]
                        _ -> []
                        end)
  end


  defp vadd({x0, y0}, {x1, y1}), do: {x0 + x1, y0 + y1}

end
