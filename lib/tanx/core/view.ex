defmodule Tanx.Core.View do

  defstruct my_player: nil, other_players: [], arena: nil

  defmodule Player do
    defstruct name: "", kills: 0, deaths: 0
  end

  defmodule Arena do
    defstruct radius: 10.0, my_tank: nil, objects: []
  end

  defmodule Tank do
    defstruct x: 0.0, y: 0.0, a: 0.0, v: 0.0, av: 0.0
  end

end
