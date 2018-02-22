defmodule Tanx.Game.Events.ArenaUpdated do
  defstruct(
    time: nil,
    arena: nil
  )
end

defmodule Tanx.Game.Events.TankCreated do
  defstruct(
    id: nil,
    tank: nil,
    event_data: nil
  )
end

defmodule Tanx.Game.Events.TankDeleted do
  defstruct(
    id: nil,
    tank: nil,
    event_data: nil
  )
end

defmodule Tanx.Game.Events.PowerUpCollected do
  defstruct(
    id: nil,
    power_up: nil,
    tank_id: nil,
    tank: nil
  )
end
