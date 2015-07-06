defmodule Tanx.TankUpdateTest do
  use ExUnit.Case

  setup do
    {:ok, game} = Tanx.Core.Game.start_link(clock_interval: -1)
    game |> Tanx.Core.Game.advance_to_time(1000)
    {:ok, player} = game |> Tanx.Core.Game.connect(name: "daniel")
    {:ok, game: game, player: player}
  end

  test "tank remains at rest", %{game: game, player: player} do
    :ok = player |> Tanx.Core.Player.new_tank()
    game |> Tanx.Core.Game.advance_to_time(2000)
    {:ok, view} = player |> Tanx.Core.Player.view()
    assert view == _create_view(0, 0, 0, 0, 0)
  end

  test "tank moves forward with constant velocity", %{game: game, player: player} do
    :ok = player |> Tanx.Core.Player.new_tank()
    :ok = player |> Tanx.Core.Player.control_tank(v: 1.0)
    game |> Tanx.Core.Game.advance_to_time(2000)
    {:ok, view} = player |> Tanx.Core.Player.view()
    assert view == _create_view(1, 0, 0, 1, 0)
    game |> Tanx.Core.Game.advance_to_time(4000)
    {:ok, view} = player |> Tanx.Core.Player.view()
    assert view == _create_view(3, 0, 0, 1, 0)
  end

  test "tank rotates with constant velocity", %{game: game, player: player} do
    :ok = player |> Tanx.Core.Player.new_tank()
    :ok = player |> Tanx.Core.Player.control_tank(av: -0.5)
    game |> Tanx.Core.Game.advance_to_time(2000)
    {:ok, view} = player |> Tanx.Core.Player.view()
    assert view == _create_view(0, 0, -0.5, 0, -0.5)
    game |> Tanx.Core.Game.advance_to_time(4000)
    {:ok, view} = player |> Tanx.Core.Player.view()
    assert view == _create_view(0, 0, -1.5, 0, -0.5)
  end


  # Utils

  defp _create_view(x, y, a, v, av) do
    %Tanx.Core.View{my_player: %Tanx.Core.View.Player{name: "daniel"},
      arena: %Tanx.Core.View.Arena{my_tank: %Tanx.Core.View.Tank{x: x, y: y, a: a, v: v, av: av}}}
  end

end
