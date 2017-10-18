defmodule Tanx.BasicTanksTest do
  use ExUnit.Case


  setup do
    time_config = Tanx.SystemTime.new_config
    {:ok, game} = Tanx.Game.start_link(clock_interval: nil, time_config: time_config)
    {:ok, game: game, time_config: time_config}
  end


  test "one player and a tank", %{game: game} do
    {:ok, player1} = game |> Tanx.Game.connect(name: "daniel")
    assert player1 |> Tanx.Player.has_tank?() == false

    :ok = player1 |> Tanx.Player.new_tank()
    assert player1 |> Tanx.Player.has_tank?() == true

    :ok = game |> Tanx.Game.manual_clock_tick(1000)
    view = player1 |> Tanx.Player.view_arena_objects()
    assert view == %Tanx.View.Arena{tanks: [
      %Tanx.View.Tank{is_me: true, name: "daniel", armor: 1.0}
    ]}
  end


  test "two players and tanks", %{game: game} do
    {:ok, player1} = game |> Tanx.Game.connect(name: "daniel")
    {:ok, player2} = game |> Tanx.Game.connect(name: "greg")
    :ok = player1 |> Tanx.Player.new_tank()
    :ok = player2 |> Tanx.Player.new_tank(x: 2)
    :ok = game |> Tanx.Game.manual_clock_tick(1000)
    view = player1 |> Tanx.Player.view_arena_objects()
    got = view.tanks |> Enum.into(MapSet.new)
    want = [
      %Tanx.View.Tank{is_me: true, name: "daniel", armor: 1.0},
      %Tanx.View.Tank{is_me: false, name: "greg", x: 2.0, armor: 1.0}
    ] |> Enum.into(MapSet.new)
    assert MapSet.equal?(got, want)
  end


  test "disconnecting a player should remove the tank", %{game: game} do
    {:ok, player1} = game |> Tanx.Game.connect(name: "daniel")
    {:ok, player2} = game |> Tanx.Game.connect(name: "greg")
    :ok = player1 |> Tanx.Player.new_tank()
    :ok = game |> Tanx.Game.manual_clock_tick(1000)

    player1 |> Tanx.Player.leave()
    :ok = game |> Tanx.Game.manual_clock_tick(2000)
    view = player2 |> Tanx.Player.view_arena_objects()
    assert view == %Tanx.View.Arena{}
  end


  test "one player fires a missile", %{game: game} do
    {:ok, player1} = game |> Tanx.Game.connect(name: "Kyle")
    :ok = player1 |> Tanx.Player.new_tank()
    :ok = player1 |> Tanx.Player.new_missile()
    assert player1 |> Tanx.Player.missile_count == 1
    :ok = game |> Tanx.Game.manual_clock_tick(500)

    view = player1 |> Tanx.Player.view_arena_objects()
    assert view == %Tanx.View.Arena{
      missiles: [
        %Tanx.View.Missile{is_mine: true, x: 5.5, hx: 10.0}
      ],
      tanks: [
        %Tanx.View.Tank{is_me: true, name: "Kyle", armor: 1.0}
      ]
    }
  end


  test "one player fires missiles too quickly", %{game: game} do
    {:ok, player1} = game |> Tanx.Game.connect(name: "Kyle")
    :ok = player1 |> Tanx.Player.new_tank()
    assert :ok = player1 |> Tanx.Player.new_missile()
    assert :at_limit = player1 |> Tanx.Player.new_missile()
    assert player1 |> Tanx.Player.missile_count == 1

    :ok = game |> Tanx.Game.manual_clock_tick(500)

    view = player1 |> Tanx.Player.view_arena_objects()
    assert view == %Tanx.View.Arena{
      missiles: [
        %Tanx.View.Missile{is_mine: true, x: 5.5, hx: 10.0},
      ],
      tanks: [
        %Tanx.View.Tank{is_me: true, name: "Kyle", armor: 1.0}
      ]
    }
  end


  test "one player fires 2 missiles", %{game: game} do
    {:ok, player1} = game |> Tanx.Game.connect(name: "Kyle")
    :ok = player1 |> Tanx.Player.new_tank()
    :ok = player1 |> Tanx.Player.new_missile()
    :ok = game |> Tanx.Game.manual_clock_tick(500)
    :ok = player1 |> Tanx.Player.new_missile()
    assert player1 |> Tanx.Player.missile_count == 2

    :ok = game |> Tanx.Game.manual_clock_tick(800)

    view = player1 |> Tanx.Player.view_arena_objects()
    assert Enum.count(view.missiles) == 2
    assert Enum.member?(view.missiles,
      %Tanx.View.Missile{is_mine: true, x: 3.5, hx: 10.0})
    assert Enum.member?(view.missiles,
      %Tanx.View.Missile{is_mine: true, x: 8.5, hx: 10.0})
  end


  test "one player fires a missile without tank", %{game: game} do
    {:ok, player1} = game |> Tanx.Game.connect(name: "Kyle")
    assert :no_tank == player1 |> Tanx.Player.new_missile()
    assert player1 |> Tanx.Player.missile_count == 0
  end

end
