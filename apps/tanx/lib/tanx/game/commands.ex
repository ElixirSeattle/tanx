defmodule Tanx.Game.Commands.Defer do
  defstruct(
    event: nil
  )
end

defmodule Tanx.Game.Commands.CreateTank do
  defstruct(
    entry_point_name: nil,
    radius: 0.5,
    collision_radius: 0.6,
    armor: 1.0,
    max_armor: 1.0,
    data: nil,
    event_data: nil
  )
end

defmodule Tanx.Game.Commands.DeleteTank do
  defstruct(
    id: nil,
    query: nil,
    event_data: nil
  )
end

defmodule Tanx.Game.Commands.SetTankVelocity do
  defstruct(
    id: nil,
    velocity: 0.0,
    angular_velocity: 0.0
  )
end

defmodule Tanx.Game.Commands.ExplodeTank do
  defstruct(
    id: nil,
    explosion_intensity: 0.0,
    explosion_radius: 0.0,
    explosion_length: 0.0,
    chain_data: nil
  )
end

defmodule Tanx.Game.Commands.FireMissile do
  defstruct(
    tank_id: nil,
    heading: nil,
    velocity: 0.0,
    bounce: 0,
    impact_intensity: 0.0,
    explosion_intensity: 0.0,
    explosion_radius: 0.0,
    explosion_length: 0.0,
    chain_data: nil
  )
end

defmodule Tanx.Game.Commands.CreatePowerUp do
  defstruct(
    pos: {0.0, 0.0},
    radius: 0.4,
    expires_in: 0.0,
    tank_modifier: nil,
    data: nil
  )
end
