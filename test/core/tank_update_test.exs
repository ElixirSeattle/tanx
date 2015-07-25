defmodule Tanx.TankUpdateTest do
  use ExUnit.Case

  @epsilon 0.00001


  setup do
    structure = %Tanx.Core.Structure{
      height: 20.0, width: 20.0,
      walls: [
        [{-5, -1}, {-5, 1}]
      ]
    }
    {:ok, game} = Tanx.Core.Game.start_link(clock_interval: nil, structure: structure)
    game |> Tanx.Core.Game.manual_clock_tick(1000)
    {:ok, player} = game |> Tanx.Core.Game.connect(name: "daniel")
    {:ok, game: game, player: player}
  end

  test "tank remains at rest", %{game: game, player: player} do
    :ok = player |> Tanx.Core.Player.new_tank()
    game |> Tanx.Core.Game.manual_clock_tick(2000)
    _check_tank(player, 0.0, 0.0, 0.0)
  end

  test "tank moves forward with constant velocity", %{game: game, player: player} do
    :ok = player |> Tanx.Core.Player.new_tank()
    :ok = player |> Tanx.Core.Player.control_tank(:forward, true)
    game |> Tanx.Core.Game.manual_clock_tick(2000)
    _check_tank(player, 2.0, 0.0, 0.0)
    game |> Tanx.Core.Game.manual_clock_tick(4000)
    _check_tank(player, 6.0, 0.0, 0.0)
  end

  test "tank stops at arena edge", %{game: game, player: player} do
    :ok = player |> Tanx.Core.Player.new_tank()
    :ok = player |> Tanx.Core.Player.control_tank(:forward, true)
    game |> Tanx.Core.Game.manual_clock_tick(5500)
    _check_tank(player, 9.0, 0.0, 0.0)
    game |> Tanx.Core.Game.manual_clock_tick(6000)
    _check_tank(player, 9.5, 0.0, 0.0)
    game |> Tanx.Core.Game.manual_clock_tick(6500)
    _check_tank(player, 9.5, 0.0, 0.0)
  end

  test "tank rotates with constant velocity", %{game: game, player: player} do
    :ok = player |> Tanx.Core.Player.new_tank()
    :ok = player |> Tanx.Core.Player.control_tank(:right, true)
    game |> Tanx.Core.Game.manual_clock_tick(1500)
    _check_tank(player, 0.0, 0.0, -1.0)
    game |> Tanx.Core.Game.manual_clock_tick(2500)
    _check_tank(player, 0.0, 0.0, -3.0)
  end

  test "tank stops at wall", %{game: game, player: player} do
    pi = :math.pi();
    :ok = player |> Tanx.Core.Player.new_tank(heading: pi)
    :ok = player |> Tanx.Core.Player.control_tank(:forward, true)
    game |> Tanx.Core.Game.manual_clock_tick(3000)
    _check_tank(player, -4.0, 0.0, pi)
    game |> Tanx.Core.Game.manual_clock_tick(3250)
    _check_tank(player, -4.4, 0.0, pi)
    game |> Tanx.Core.Game.manual_clock_tick(3300)
    _check_tank(player, -4.4, 0.0, pi)
  end


  # Utils

  defp _check_tank(player, x, y, heading) do
    view = player |> Tanx.Core.Player.view_arena()
    got = view.tanks |> hd()
    want = %Tanx.Core.View.Tank{is_me: true, name: "daniel", x: x, y: y, heading: heading}
    assert_in_delta(got.x, want.x, @epsilon)
    assert_in_delta(got.y, want.y, @epsilon)
  end

end
