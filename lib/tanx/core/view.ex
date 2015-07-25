defmodule Tanx.Core.View do

  # This is a collection of structs that represent views returned from Game and Player
  # view calls.


  defmodule Player do
    @moduledoc """
    A view of a player.
    """
    defstruct name: "", is_me: false, kills: 0, deaths: 0
  end


  defmodule Structure do
    @moduledoc """
    A view of the arena structure.
    """
    defstruct height: 0.0,
              width: 0.0,
              walls: []

    def from_structure(struct) do
      walls = struct.walls
        |> Enum.map(fn wall ->
          wall |> Enum.flat_map(&Tuple.to_list/1)
        end)
      %Structure{height: struct.height, width: struct.width, walls: walls}
    end
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
    defstruct is_mine: false, name: "", x: 0.0, y: 0.0, heading: 0.0
  end

end
