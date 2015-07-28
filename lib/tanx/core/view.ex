defmodule Tanx.Core.View do

  # This is a collection of structs that represent views returned from Game and Player
  # view calls.


  defmodule Player do
    @moduledoc """
    A view of a player.
    """
    defstruct name: "",
              is_me: false,
              kills: 0,
              deaths: 0
  end


  defmodule Structure do
    @moduledoc """
    A view of the arena structure.
    """
    defstruct height: 20.0,
              width: 20.0,
              walls: [],
              entry_point_radius: 0.5,
              entry_points: []
  end


  defmodule EntryPoint do
    @moduledoc """
    A view of an entry point.
    """
    defstruct name: "",
              x: 0.0,
              y: 0.0
  end


  defmodule Arena do
    @moduledoc """
    A view of the arena state.
    """
    defstruct tanks: [],
              missiles: [],
              explosions: [],
              entry_points_available: %{}
  end


  defmodule Tank do
    @moduledoc """
    A view of a tank.
    """
    defstruct is_me: false,
              name: "",
              x: 0.0,
              y: 0.0,
              heading: 0.0,
              radius: 0.5
  end


  defmodule Missile do
    @moduledoc """
    A view of a missile.
    """
    defstruct is_mine: false,
              x: 0.0,
              y: 0.0,
              heading: 0.0
  end


  defmodule Explosion do
    @moduledoc """
    A view of an explosion.
    """
    defstruct x: 0.0,
              y: 0.0,
              radius: 1.0,
              age: 0.0
  end


end
