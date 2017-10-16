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

  defmodule MapDetails do
    pi = :math.pi()
    defstruct maps: [
                # A maze with diagonal passages and an open area in the center.
                %Tanx.Core.Structure{
                  width: 20.0,height: 20.0,

                  walls: [
                    [
                      {10, 10}, {5.5, 10}, {5.5, 8}, {5, 8}, {5, 10}, {-8, 10}, {-8, 7}, {-8.5, 7}, {-8.5, 10},
                      {-10, 10}, {-10, 5.5}, {-8, 5.5}, {-8, 5}, {-10, 5}, {-10, -8}, {-7, -8}, {-7, -8.5}, {-10, -8.5},
                      {-10, -10}, {-5.5, -10}, {-5.5, -8}, {-5, -8}, {-5, -10}, {8, -10}, {8, -7}, {8.5, -7}, {8.5, -10},
                      {10, -10}, {10, -5.5}, {8, -5.5}, {8, -5}, {10, -5}, {10, 8}, {7, 8}, {7, 8.5}, {10, 8.5}
                    ],

                    [{-8, 3}, {-4.5, 3}, {-5, 4}, {-1, 4}, {-5, 4}, {-3, 0}, {-4.5, 3}],
                    [{8, -3}, {4.5, -3}, {5, -4}, {1, -4}, {5, -4}, {3, 0}, {4.5, -3}],

                    [{-6, 6}, {-6, 8}, {-3, 8}, {-6, 8}],
                    [{6, -6}, {6, -8}, {3, -8}, {6, -8}],

                    [{-8, 1}, {-5.5, 1}, {-4, -2}, {-5.5, 1}],
                    [{8, -1}, {5.5, -1}, {4, 2}, {5.5, -1}],

                    [{-4, 6}, {0, 6}, {1, 4}, {3, 4}, {1, 4}, {0, 6}],
                    [{4, -6}, {0, -6}, {-1, -4}, {-3, -4}, {-1, -4}, {0, -6}],

                    [{4, 6}, {6, 2}],
                    [{-4, -6}, {-6, -2}],

                    [{7.5, 3}, {6, 6}, {8, 6}, {6, 6}],
                    [{-7.5, -3}, {-6, -6}, {-8, -6}, {-6, -6}],

                    [{2, 6}, {1, 8}, {3, 8}, {1, 8}],
                    [{-2, -6}, {-1, -8}, {-3, -8}, {-1, -8}],

                    [{-1, 10}, {-1, 8}],
                    [{1, -10}, {1, -8}],

                    [{10, 1}, {8, 1}],
                    [{-10, -1}, {-8, -1}],
                  ],

                  entry_points: [
                    %Tanx.Core.Structure.EntryPoint{
                      name: "nw",
                      x: -9.25, y: 9.25, heading: -pi/2,
                      buffer_left: 0.75, buffer_right: 1.25, buffer_up: 0.75, buffer_down: 4.25
                    },
                    %Tanx.Core.Structure.EntryPoint{
                      name: "ne",
                      x: 9.25, y: 9.25, heading: pi,
                      buffer_left: 4.25, buffer_right: 0.75, buffer_up: 0.75, buffer_down: 1.25
                    },
                    %Tanx.Core.Structure.EntryPoint{
                      name: "se",
                      x: 9.25, y: -9.25, heading: pi/2,
                      buffer_left: 1.25, buffer_right: 0.75, buffer_up: 4.25, buffer_down: 0.75
                    },
                    %Tanx.Core.Structure.EntryPoint{
                      name: "sw",
                      x: -9.25, y: -9.25, heading: 0.0,
                      buffer_left: 0.75, buffer_right: 4.25, buffer_up: 1.25, buffer_down: 0.75
                    },
                  ]
                },
                %Tanx.Core.Structure{
                  width: 20.0,height: 20.0,

                  walls: [
                    [
                      {10, 10}, {-10, 10}, {-10, -10}, {10, -10}
                    ],

                    [{-10, 8}, {-8, 8}],
                    [{10, 8}, {8, 8}],
                    [{10, -8}, {8, -8}],
                    [{-10, -8}, {-8, -8}],

                    [{-8.5, 6}, {-7, 6}, {-7, 3},{-6, 3}, {-7, 3}, {-7, 6}],
                    [{8.5, 6}, {7, 6}, {7, 3},{6, 3}, {7, 3}, {7, 6}],
                    [{8.5, -6}, {7, -6}, {7, -3},{6, -3}, {7, -3}, {7, -6}],
                    [{-8.5, -6}, {-7, -6}, {-7, -3},{-6, -3}, {-7, -3}, {-7, -6}],

                    [{-5, 4.5}, {-5, 8}, {-3, 8}, {-5, 8}],
                    [{5, 4.5}, {5, 8}, {3, 8}, {5, 8}],
                    [{5, -4.5}, {5, -8}, {3, -8}, {5, -8}],
                    [{-5, -4.5}, {-5, -8}, {-3, -8}, {-5, -8}],

                    [{-3, 5}, {-2, 3}],
                    [{3, 5}, {2, 3}],
                    [{3, -5}, {2, -3}],
                    [{-3, -5}, {-2, -3}],

                    [{-2, 1}, {-1, 2}, {0, 2}, {-1, 2}],
                    [{2, 1}, {1, 2}, {0, 2}, {1, 2}],
                    [{2, -1}, {1, -2}, {0, -2}, {1, -2}],
                    [{-2, -1}, {-1, -2}, {0, -2}, {-1, -2}],

                    [{-2, 6.5}, {0, 6.5}],
                    [{2, 6.5}, {0, 6.5}],
                    [{2, -6.5}, {0, -6.5}],
                    [{-2, -6.5}, {0, -6.5}],

                    [{0, 6.5}, {0, 10}],
                    [{0, -6.5}, {0, -10}],

                    [{0, 3.5}, {0, 5}],
                    [{0, -3.5}, {0, -5}],

                    [{-5, 1}, {-5, -1}],
                    [{5, 1}, {5, -1}],

                    [{-8.5, -1}, {-8.5, 0}, {-7, 0}, {-7, 1}, {-7, 0}, {-8.5, 0}],
                    [{8.5, -1}, {8.5, 0}, {7, 0}, {7, 1}, {7, 0}, {8.5, 0}],
                  ],

                  entry_points: [
                    %Tanx.Core.Structure.EntryPoint{
                      name: "nw",
                      x: -9.25, y: 9.25, heading: 0.0,
                      buffer_left: 0.75, buffer_right: 1.25, buffer_up: 0.75, buffer_down: 4.25
                    },
                    %Tanx.Core.Structure.EntryPoint{
                      name: "ne",
                      x: 9.25, y: 9.25, heading: pi,
                      buffer_left: 4.25, buffer_right: 0.75, buffer_up: 0.75, buffer_down: 1.25
                    },
                    %Tanx.Core.Structure.EntryPoint{
                      name: "se",
                      x: 9.25, y: -9.25, heading: pi,
                      buffer_left: 1.25, buffer_right: 0.75, buffer_up: 4.25, buffer_down: 0.75
                    },
                    %Tanx.Core.Structure.EntryPoint{
                      name: "sw",
                      x: -9.25, y: -9.25, heading: 0.0,
                      buffer_left: 0.75, buffer_right: 4.25, buffer_up: 1.25, buffer_down: 0.75
                    },
                  ]
                }
              ]

  end

end
