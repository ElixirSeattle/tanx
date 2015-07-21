defmodule Tanx.MissileUpdateTest do
  use ExUnit.Case

  setup do
    {:ok, game} = Tanx.Core.Game.start_link(clock_interval: nil)
    game |> Tanx.Core.Game.manual_clock_tick(1000)
    {:ok, player} = game |> Tanx.Core.Game.connect(name: "Ben")
    {:ok, game: game, player: player}
  end

  test "missile moves at constant velocity", %{game: game, player: player} do
    :ok = player |> Tanx.Core.Player.new_tank()
    :ok = player |> Tanx.Core.Player.new_missile()

    game |> Tanx.Core.Game.manual_clock_tick(2000)
    _check_missile(player, 1.0, 0.0, 0.0)
  end

  test "missile moves on an angle with constant velocity", %{game: game, player: player} do
    :ok = player |> Tanx.Core.Player.new_tank()
    :ok = player |> Tanx.Core.Player.control_tank(:right, true)
    
    game |> Tanx.Core.Game.manual_clock_tick(2000)
    :ok = player |> Tanx.Core.Player.new_missile()
    game |> Tanx.Core.Game.manual_clock_tick(4000)
    _check_missile(player, -0.8322936730942848, -1.8185948536513634, -2.0) #Need to double check these numbers
  end


  # Utils

  defp _check_missile(player, x, y, a) do
    view = player |> Tanx.Core.Player.view_arena()
    got = view.missiles |> hd()
    want = %Tanx.Core.View.Missile{is_mine: true, name: "Ben", x: x, y: y, heading: a}
    assert got == want
  end

end
