defprotocol Tanx.Updater.CommandHandler do
  def handle(command, arena, internal_data, time)
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

defimpl Tanx.Updater.CommandHandler, for: Tanx.Updater.ExplodeTank do
  def handle(command, arena, internal_data, _time) do
    tanks = arena.tanks
    explosions = arena.explosions
    tank_id = command.id
    tank = Map.get(tanks, tank_id)
    if tank != nil do
      new_tanks = Map.delete(tanks, tank_id)
      explosion = %Tanx.Arena.Explosion{
        pos: tank.pos,
        intensity: command.explosion_intensity,
        radius: command.explosion_radius,
        length: command.explosion_length,
        data: command.chain_data
      }
      explosion_id = Tanx.Util.ID.create(explosions)
      new_explosions = Map.put(explosions, explosion_id, explosion)
      new_arena = %Tanx.Arena{arena | tanks: new_tanks, explosions: new_explosions}
      chain_data = command.chain_data
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
