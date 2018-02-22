defprotocol Tanx.Game.CommandHandler do
  def handle(command, arena, internal_data, time)
end

defimpl Tanx.Game.CommandHandler, for: Tanx.Game.Commands.Defer do
  def handle(command, arena, internal_data, _time) do
    {arena, internal_data, [command.event]}
  end
end

defimpl Tanx.Game.CommandHandler, for: Tanx.Game.Commands.CreateTank do
  def handle(command, arena, internal_data, _time) do
    entry_point_name = command.entry_point_name
    case Map.get(arena.entry_points, entry_point_name) do
      %Tanx.Game.Arena.EntryPoint{available: true} = entry_point ->
        tank = %Tanx.Game.Arena.Tank{
          pos: entry_point.pos,
          heading: entry_point.heading,
          radius: command.radius,
          collision_radius: command.collision_radius,
          armor: command.armor,
          max_armor: command.max_armor,
          data: command.data
        }
        id = Tanx.Util.ID.create("T", arena.tanks)
        entry_point = %Tanx.Game.Arena.EntryPoint{entry_point | available: false}
        new_arena = %Tanx.Game.Arena{arena |
          tanks: Map.put(arena.tanks, id, tank),
          entry_points: Map.put(arena.entry_points, entry_point_name, entry_point)
        }
        event_data = command.event_data
        events =
          if event_data == nil do
            []
          else
            [%Tanx.Game.Events.TankCreated{id: id, event_data: event_data}]
          end
        {new_arena, internal_data, events}
      _ ->
        {arena, internal_data, []}
      end
  end
end

defimpl Tanx.Game.CommandHandler, for: Tanx.Game.Commands.DeleteTank do
  def handle(command, arena, internal_data, _time) do
    tanks = arena.tanks
    id = command.id
    tank = Map.get(tanks, id)
    if tank != nil do
      new_arena = %Tanx.Game.Arena{arena | tanks: Map.delete(tanks, id)}
      event_data = command.event_data
      events =
        if event_data == nil do
          []
        else
          [%Tanx.Game.Events.TankDeleted{id: id, event_data: event_data}]
        end
      {new_arena, internal_data, events}
    else
      {arena, internal_data, []}
    end
  end
end

defimpl Tanx.Game.CommandHandler, for: Tanx.Game.Commands.SetTankVelocity do
  def handle(command, arena, internal_data, _time) do
    tanks = arena.tanks
    id = command.id
    tank = Map.get(tanks, id)
    arena =
      if tank != nil do
        tank = %Tanx.Game.Arena.Tank{tank |
          velocity: command.velocity,
          angular_velocity: command.angular_velocity
        }
        %Tanx.Game.Arena{arena | tanks: Map.put(tanks, id, tank)}
      else
        arena
      end
    {arena, internal_data, []}
  end
end

defimpl Tanx.Game.CommandHandler, for: Tanx.Game.Commands.ExplodeTank do
  def handle(command, arena, internal_data, _time) do
    tanks = arena.tanks
    explosions = arena.explosions
    tank_id = command.id
    tank = Map.get(tanks, tank_id)
    if tank != nil do
      chain_data = command.chain_data
      new_tanks = Map.delete(tanks, tank_id)
      explosion = %Tanx.Game.Arena.Explosion{
        pos: tank.pos,
        intensity: command.explosion_intensity,
        radius: command.explosion_radius,
        length: command.explosion_length,
        data: chain_data
      }
      explosion_id = Tanx.Util.ID.create("E", explosions)
      new_explosions = Map.put(explosions, explosion_id, explosion)
      new_arena = %Tanx.Game.Arena{arena | tanks: new_tanks, explosions: new_explosions}
      events =
        if chain_data == nil do
          []
        else
          [%Tanx.Game.Events.TankDeleted{id: tank_id, tank: tank, event_data: chain_data}]
        end
      {new_arena, internal_data, events}
    else
      {arena, internal_data, []}
    end
  end
end

defimpl Tanx.Game.CommandHandler, for: Tanx.Game.Commands.FireMissile do
  @epsilon 0.00001

  def handle(command, arena, internal_data, _time) do
    tank = Map.get(arena.tanks, command.tank_id)
    new_arena =
      if tank == nil do
        arena
      else
        {x, y} = tank.pos
        heading = command.heading || tank.heading
        dist = tank.radius + @epsilon
        pos = {x + dist * :math.cos(heading), y + dist * :math.sin(heading)}
        missile = %Tanx.Game.Arena.Missile{
          pos: pos,
          heading: heading,
          velocity: command.velocity,
          bounce: command.bounce,
          impact_intensity: command.impact_intensity,
          explosion_intensity: command.explosion_intensity,
          explosion_radius: command.explosion_radius,
          explosion_length: command.explosion_length,
          data: command.chain_data
        }
        missiles = arena.missiles
        missile_id = Tanx.Util.ID.create("M", missiles)
        new_missiles = Map.put(missiles, missile_id, missile)
        %Tanx.Game.Arena{arena | missiles: new_missiles}
      end
    {new_arena, internal_data, []}
  end
end

defimpl Tanx.Game.CommandHandler, for: Tanx.Game.Commands.CreatePowerUp do
  def handle(command, arena, internal_data, _time) do
    power_up = %Tanx.Game.Arena.PowerUp{
      pos: command.pos,
      radius: command.radius,
      expires_in: command.expires_in,
      tank_modifier: command.tank_modifier,
      data: command.data
    }
    power_ups = arena.power_ups
    power_up_id = Tanx.Util.ID.create("U", power_ups)
    new_power_ups = Map.put(power_ups, power_up_id, power_up)
    {%Tanx.Game.Arena{arena | power_ups: new_power_ups}, internal_data, []}
  end
end
