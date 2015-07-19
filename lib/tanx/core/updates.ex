defmodule Tanx.Core.Updates do

  # This is a collection of structs that represent updates sent from arena objects
  # back to the arena updater, describing how they have updated themselves.

  defmodule MoveTank do
    @moduledoc """
    An update command that moves the current tank.
    """
    defstruct player: nil, x: 0.0, y: 0.0, heading: 0.0, radius: 0.5
  end

end
