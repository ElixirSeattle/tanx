defmodule Tanx.Core.PowerUpTypes do

  # This is a collection of structs that represent power ups
  defmodule BouncingMissile do
    @moduledoc """
    An update command that moves the current tank.
    """
    defstruct name: "Bouncing Missile",
              bounce_count: 1
  end
end
