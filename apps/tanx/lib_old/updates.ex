defmodule Tanx.Updates do

  # This is a collection of structs that represent updates sent from arena objects
  # back to the arena updater, describing how they have updated themselves.

  defmodule MoveTank do
    @moduledoc """
    An update command that moves the current tank.
    """
    defstruct tank: nil,
              player: nil,
              pos: {0.0, 0.0},
              heading: 0.0,
              radius: 0.5,
              armor: 0.0,
              max_armor: 1.0,
              force: {0.0, 0.0},
              tread: 0.0
  end


  defmodule Explosion do
    @moduledoc """
    An update command that advances an explosion.
    """
    defstruct pos: {0.0, 0.0},
              radius: 1.0,
              intensity: 1.0,
              starting: false,
              chain_radius: nil,
              age: 0.0,
              originator: nil
  end


  defmodule MoveMissile do
    @moduledoc """
    An update command that moves the missile along its path.
    """
    defstruct missile: nil,
              player: nil,
              strength: 1.0,
              pos: {0.0, 0.0},
              heading: 0.0
  end

  defmodule PowerUp do
    @moduledoc """
    An update command that gathers the details of the power up along its path.
    """
    defstruct powerup: nil,
              pos: {0.0, 0.0},
              radius: 0.4,
              type: nil,
              created_at: nil
  end
end
