defmodule Tanx.MissileUpdateTest do
  use ExUnit.Case

  setup do
    structure = %Tanx.Structure{
      height: 20.0, width: 20.0,
      walls: [
       [{-5, -3}, {-5, 3}]
      ]
    }
    {:ok, game} = Tanx.Game.start_link(clock_interval: nil, structure: structure)
    game |> Tanx.Game.manual_clock_tick(1000)
    {:ok, player} = game |> Tanx.Game.connect(name: "Ben")
    :ok = player |> Tanx.Player.new_tank()
    {:ok, game: game, player: player}
  end

  test "missile moves at constant velocity", %{game: game, player: player} do
    assert :ok == player |> Tanx.Player.new_missile()

    game |> Tanx.Game.manual_clock_tick(1100)

    _check_missile(player, 1.5, 0.0, {10.0, 0.0})
  end

  test "missile moves on an angle with constant velocity", %{game: game, player: player} do
    :ok = player |> Tanx.Player.control_tank(:right, true)
    game |> Tanx.Game.manual_clock_tick(1500)
    assert :ok = player |> Tanx.Player.new_missile()
    game |> Tanx.Game.manual_clock_tick(2000)
    # Missile has been created at the origin
    _check_missile(player, 2.97, -4.63, {5.4, -8.41})
    game |> Tanx.Game.manual_clock_tick(2100)
    # Missile should have changed position, but maintained the same angle.
    # View rounds to hundredths.
    _check_missile(player, 3.51, -5.47, {5.4, -8.41})
  end

  test "missile explodes on impact with obstacle", %{game: game, player: player} do
    :ok = player |> Tanx.Player.control_tank(:right, true)
    assert :ok == game |> Tanx.Game.manual_clock_tick(2570)
    assert :ok == player |> Tanx.Player.new_missile()
    assert :ok == game |> Tanx.Game.manual_clock_tick(2670)
    player |> _check_missile(-1.5, 0.0, {-10.0, -0.02})
    assert :ok == game |> Tanx.Game.manual_clock_tick(2770)

    player |> _check_missile(-2.5, -0.0, {-10.0, -0.02})
    assert :ok == game |> Tanx.Game.manual_clock_tick(3080)
    view = player |> Tanx.Player.view_arena_objects()
    assert view.missiles == []
  end

  test "missle explodes on impact with wall", %{game: game, player: player} do
    :ok = player |> Tanx.Player.control_tank(:right, true)
    assert :ok == game |> Tanx.Game.manual_clock_tick(1785)
    assert :ok == player |> Tanx.Player.new_missile()
    assert :ok == game |> Tanx.Game.manual_clock_tick(2185)
    player |> _check_missile(0.0, -4.5, {0.01, -10.0})
    assert :ok == game |> Tanx.Game.manual_clock_tick(2275)
    player |> _check_missile(0.0, -5.4, {0.01, -10.0})
    assert :ok == game |> Tanx.Game.manual_clock_tick(3000)
    view = player |> Tanx.Player.view_arena_objects()
    assert view.missiles == []
  end

  # Utils

  defp _check_missile(player, x, y, {hx, hy}) do
    view = player |> Tanx.Player.view_arena_objects()
    assert view != []
    got = view.missiles |> hd()
    want = %Tanx.View.Missile{is_mine: true, x: x, y: y, hx: hx, hy: hy}
    assert got == want
  end

end
