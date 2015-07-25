defmodule Tanx.Core.Structure do

  @moduledoc """
  The Structure module defines the static structure of an arena, including its size, shape,
  and walls.
  """

  defstruct width: 20.0,
            height: 20.0,
            walls: []

end
