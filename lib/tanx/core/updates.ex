defmodule Tanx.Core.Updates do

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
              force: {0.0, 0.0}
  end


  defmodule Explosion do
    @moduledoc """
    An update command that advances an explosion.
    """
    defstruct pos: {0.0, 0.0},
              radius: 1.0,
              age: 0.0
  end


  defmodule MoveMissile do
    @moduledoc """
    An update command that moves the missile along its path.
    """
    defstruct player: nil, x: 0.0, y: 0.0, heading: 0.0
  end

end
