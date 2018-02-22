defmodule Tanx.Game.Arena do

  defstruct(
    size: {20.0, 20.0},
    walls: [],
    entry_points: %{},
    tanks: %{},
    missiles: %{},
    explosions: %{},
    power_ups: %{}
  )

  defmodule EntryPoint do
    defstruct(
      pos: {0.0, 0.0},
      heading: 0.0,
      buffer_left: 0.0,
      buffer_right: 0.0,
      buffer_up: 0.0,
      buffer_down: 0.0,
      available: true
    )
  end

  defmodule Tank do
    defstruct(
      pos: {0.0, 0.0},
      radius: 0.5,
      collision_radius: 0.6,
      heading: 0.0,
      velocity: 0.0,
      angular_velocity: 0.0,
      armor: 1.0,
      max_armor: 1.0,
      dist: 0.0,
      data: nil
    )
  end

  defmodule Missile do
    defstruct(
      pos: {0.0, 0.0},
      heading: 0.0,
      velocity: 0.0,
      bounce: 0,
      impact_intensity: 0.0,
      explosion_intensity: 0.0,
      explosion_radius: 0.0,
      explosion_length: 0.0,
      age: 0.0,
      data: nil
    )
  end

  defmodule Explosion do
    defstruct(
      pos: {0.0, 0.0},
      intensity: 0.0,
      radius: 0.0,
      length: 0.0,
      progress: 0.0,
      data: nil
    )
  end

  defmodule PowerUp do
    defstruct(
      pos: {0.0, 0.0},
      radius: 0.4,
      expires_in: 0.0,
      tank_modifier: nil,
      data: nil
    )
  end

end
