defmodule Tanx.MissileUpdateTest do
  use ExUnit.Case

  setup do
    structure = %Tanx.Core.Structure{
      height: 20.0, width: 20.0,
      walls: [
       [{-5, -3}, {-5, 3}]
      ]
    }
    {:ok, game} = Tanx.Core.Game.start_link(clock_interval: nil, structure: structure)
    game |> Tanx.Core.Game.manual_clock_tick(1000)
    {:ok, player} = game |> Tanx.Core.Game.connect(name: "Ben")
    :ok = player |> Tanx.Core.Player.new_tank()
    {:ok, game: game, player: player}
  end

  test "missile moves at constant velocity", %{game: game, player: player} do
    :ok = player |> Tanx.Core.Player.new_missile()

    game |> Tanx.Core.Game.manual_clock_tick(2000)

    _check_missile(player, 10.0, 0.0, 0.0)
  end

  test "missile moves on an angle with constant velocity", %{game: game, player: player} do
    :ok = player |> Tanx.Core.Player.control_tank(:right, true)
    game |> Tanx.Core.Game.manual_clock_tick(1500)
    assert :ok = player |> Tanx.Core.Player.new_missile()
    game |> Tanx.Core.Game.manual_clock_tick(2000)
    # Missile has been created at the origin
    _check_missile(player, 2.7, -4.21, -1.0)
    game |> Tanx.Core.Game.manual_clock_tick(2100)
    # Missile should have changed position, but maintained the same angle.
    # View rounds to hundredths.
    _check_missile(player, 3.24, -5.05, -1.0)
  end

  test "missile explodes on impact with obstacle", %{game: game, player: player} do
    :ok = player |> Tanx.Core.Player.control_tank(:right, true)
    assert :ok == game |> Tanx.Core.Game.manual_clock_tick(2570)
    assert :ok == player |> Tanx.Core.Player.new_missile()
    assert :ok == game |> Tanx.Core.Game.manual_clock_tick(2670)
    player |> _check_missile(-1.0, 0.0, -3.14)
    assert :ok == game |> Tanx.Core.Game.manual_clock_tick(3070)

    player |> _check_missile(-5.0, -0.01, -3.14)
    assert :ok == game |> Tanx.Core.Game.manual_clock_tick(3080)
    view = player |> Tanx.Core.Player.view_arena_objects()
    assert view.missiles == []
  end

  test "missle explodes on impact with wall", %{game: game, player: player} do
    :ok = player |> Tanx.Core.Player.control_tank(:right, true)
    assert :ok == game |> Tanx.Core.Game.manual_clock_tick(1785)
    assert :ok == player |> Tanx.Core.Player.new_missile()
    assert :ok == game |> Tanx.Core.Game.manual_clock_tick(2185)
    player |> _check_missile(0.0, -4.0, -1.57)
    assert :ok == game |> Tanx.Core.Game.manual_clock_tick(2775)
    player |> _check_missile(0.01, -9.9, -1.57)
    assert :ok == game |> Tanx.Core.Game.manual_clock_tick(5000)
    view = player |> Tanx.Core.Player.view_arena_objects()
    assert view.missiles == []
  end

  # Utils

  defp _check_missile(player, x, y, a) do
    view = player |> Tanx.Core.Player.view_arena_objects()
    assert view != []
    got = view.missiles |> hd()
    want = %Tanx.Core.View.Missile{is_mine: true, x: x, y: y, heading: a}
    assert got == want
  end

end
