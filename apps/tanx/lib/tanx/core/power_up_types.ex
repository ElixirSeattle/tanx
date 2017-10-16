defmodule Tanx.Core.PowerUpTypes do

  # This is a collection of structs that represent power ups
  defmodule BouncingMissile do
    @moduledoc """
    An update command that moves the current tank.
    """
    defstruct name: "Bouncing Missile",
              bounce_count: 1
  end

  defmodule HealthKit do
    @moduledoc """
    A power up that will restore health to the player that obtains it
    """
    defstruct name: "Health Kit"
  end
end
