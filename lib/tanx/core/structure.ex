defmodule Tanx.Core.Structure do

  @moduledoc """
  The Structure module defines the static structure of an arena, including its size, shape,
  and walls.

  Walls is a list of walls, where a wall is a list of two-element tuples {x, y}.
  The points in a wall must be in clockwise order around the wall.
  Walls are auto-closing; you do not need to repeat the first point at the end.

  Entry_points is a list of EntryPoint structures.

  """

  defstruct width: 20.0,
            height: 20.0,
            walls: [],
            entry_points: []




  defmodule EntryPoint do
    @moduledoc """
    An entry point in the structure
    """
    defstruct name: "",
              x: 0.0,
              y: 0.0,
              heading: 0.0,
              buffer_left: 0.0,
              buffer_right: 0.0,
              buffer_up: 0.0,
              buffer_down: 0.0
  end

end
