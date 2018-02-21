defprotocol Tanx.Updater.CommandHandler do
  def handle(command, arena, internal_data, time)
end

defimpl Tanx.Updater.CommandHandler, for: Tanx.Updater.Defer do
  def handle(command, arena, internal_data, _time) do
    {arena, internal_data, [command.event]}
  end
end

defimpl Tanx.Updater.CommandHandler, for: Tanx.Updater.CreateTank do
  def handle(command, arena, internal_data, _time) do
    entry_point_name = command.entry_point_name
    case Map.get(arena.entry_points, entry_point_name) do
      %Tanx.Arena.EntryPoint{available: true} = entry_point ->
        tank = %Tanx.Arena.Tank{
          pos: entry_point.pos,
          heading: entry_point.heading,
          radius: command.radius,
          collision_radius: command.collision_radius,
          armor: command.armor,
          max_armor: command.max_armor,
          data: command.data
        }
        id = Tanx.Util.ID.create(arena.tanks)
        entry_point = %Tanx.Arena.EntryPoint{entry_point | available: false}
        new_arena = %Tanx.Arena{arena |
          tanks: Map.put(arena.tanks, id, tank),
          entry_points: Map.put(arena.entry_points, entry_point_name, entry_point)
        }
        event_data = command.event_data
        events =
          if event_data == nil do
            []
          else
            [%Tanx.Updater.TankCreated{id: id, event_data: event_data}]
          end
        {new_arena, internal_data, events}
      _ ->
        {arena, internal_data, []}
      end
  end
end

defimpl Tanx.Updater.CommandHandler, for: Tanx.Updater.DeleteTank do
  def handle(command, arena, internal_data, _time) do
    tanks = arena.tanks
    id = command.id
    tank = Map.get(tanks, id)
    if tank != nil do
      new_arena = %Tanx.Arena{arena | tanks: Map.delete(tanks, id)}
      event_data = command.event_data
      events =
        if event_data == nil do
          []
        else
          [%Tanx.Updater.TankDeleted{id: id, event_data: event_data}]
        end
      {new_arena, internal_data, events}
    else
      {arena, internal_data, []}
    end
  end
end

defimpl Tanx.Updater.CommandHandler, for: Tanx.Updater.SetTankVelocity do
  def handle(command, arena, internal_data, _time) do
    tanks = arena.tanks
    id = command.id
    tank = Map.get(tanks, id)
    arena =
      if tank != nil do
        tank = %Tanx.Arena.Tank{tank |
          velocity: command.velocity,
          angular_velocity: command.angular_velocity
        }
        %Tanx.Arena{arena | tanks: Map.put(tanks, id, tank)}
      else
        arena
      end
    {arena, internal_data, []}
  end
end

defimpl Tanx.Updater.CommandHandler, for: Tanx.Updater.ExplodeTank do
  def handle(command, arena, internal_data, _time) do
    tanks = arena.tanks
    explosions = arena.explosions
    tank_id = command.id
    tank = Map.get(tanks, tank_id)
    if tank != nil do
      chain_data = command.chain_data
      new_tanks = Map.delete(tanks, tank_id)
      explosion = %Tanx.Arena.Explosion{
        pos: tank.pos,
        intensity: command.explosion_intensity,
        radius: command.explosion_radius,
        length: command.explosion_length,
        data: chain_data
      }
      explosion_id = Tanx.Util.ID.create(explosions)
      new_explosions = Map.put(explosions, explosion_id, explosion)
      new_arena = %Tanx.Arena{arena | tanks: new_tanks, explosions: new_explosions}
      events =
        if chain_data == nil do
          []
        else
          [%Tanx.Updater.TankDeleted{id: tank_id, tank: tank, event_data: chain_data}]
        end
      {new_arena, internal_data, events}
    else
      {arena, internal_data, []}
    end
  end
end

defimpl Tanx.Updater.CommandHandler, for: Tanx.Updater.FireMissile do
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
        missile = %Tanx.Arena.Missile{
          pos: pos,
          heading: heading,
          velocity: command.velocity,
          impact_intensity: command.impact_intensity,
          explosion_intensity: command.explosion_intensity,
          explosion_radius: command.explosion_radius,
          explosion_length: command.explosion_length,
          data: command.chain_data
        }
        missiles = arena.missiles
        missile_id = Tanx.Util.ID.create(missiles)
        new_missiles = Map.put(missiles, missile_id, missile)
        %Tanx.Arena{arena | missiles: new_missiles}
      end
    {new_arena, internal_data, []}
  end
end
