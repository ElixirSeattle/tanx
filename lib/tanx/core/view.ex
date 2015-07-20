defmodule Tanx.Core.View do

  # This is a collection of structs that represent views returned from Game and Player
  # view calls.


  defmodule Player do
    @moduledoc """
    A view of a player.
    """
    defstruct name: "", is_me: false, kills: 0, deaths: 0
  end


  defmodule Arena do
    @moduledoc """
    A view of the arena state.
    """
    defstruct structure: %Tanx.Core.Structure{}, tanks: [], missiles: []
  end


  defmodule Tank do
    @moduledoc """
    A view of a tank.
    """
    defstruct is_me: false, name: "", x: 0.0, y: 0.0, heading: 0.0, radius: 0.5
  end

  defmodule Missile do
    @moduledoc """
    A view of a missile.
    """
    defstruct is_mine: false, name: "", x: 0.0, y: 0.0, a: 0.0
  end

end
