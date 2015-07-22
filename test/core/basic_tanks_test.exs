defmodule Tanx.BasicTanksTest do
  use ExUnit.Case

  setup do
    {:ok, game} = Tanx.Core.Game.start_link(clock_interval: nil)
    {:ok, game: game}
  end

  test "one player and a tank", %{game: game} do
    {:ok, player1} = game |> Tanx.Core.Game.connect(name: "daniel")
    assert player1 |> Tanx.Core.Player.has_tank?() == false

    :ok = player1 |> Tanx.Core.Player.new_tank()
    assert player1 |> Tanx.Core.Player.has_tank?() == true

    :ok = game |> Tanx.Core.Game.manual_clock_tick(1000)
    view = player1 |> Tanx.Core.Player.view_arena()
    assert view == %Tanx.Core.View.Arena{tanks: [
      %Tanx.Core.View.Tank{is_me: true, name: "daniel"}
    ]}
  end

  test "two players and tanks", %{game: game} do
    {:ok, player1} = game |> Tanx.Core.Game.connect(name: "daniel")
    {:ok, player2} = game |> Tanx.Core.Game.connect(name: "greg")
    :ok = player1 |> Tanx.Core.Player.new_tank()
    :ok = player2 |> Tanx.Core.Player.new_tank()
    :ok = game |> Tanx.Core.Game.manual_clock_tick(1000)
    view = player1 |> Tanx.Core.Player.view_arena()
    got = view.tanks |> Enum.into(HashSet.new)
    want = [
      %Tanx.Core.View.Tank{is_me: true, name: "daniel"},
      %Tanx.Core.View.Tank{is_me: false, name: "greg"}
    ] |> Enum.into(HashSet.new)
    assert got == want
  end

  test "disconnecting a player should remove the tank", %{game: game} do
    {:ok, player1} = game |> Tanx.Core.Game.connect(name: "daniel")
    {:ok, player2} = game |> Tanx.Core.Game.connect(name: "greg")
    :ok = player1 |> Tanx.Core.Player.new_tank()
    :ok = game |> Tanx.Core.Game.manual_clock_tick(1000)

    player1 |> Tanx.Core.Player.leave()
    :ok = game |> Tanx.Core.Game.manual_clock_tick(2000)
    view = player2 |> Tanx.Core.Player.view_arena()
    assert view == %Tanx.Core.View.Arena{}
  end

  test "one player fires a missile", %{game: game} do
    {:ok, player1} = game |> Tanx.Core.Game.connect(name: "Kyle")
    :ok = player1 |> Tanx.Core.Player.new_tank()
    :ok = player1 |> Tanx.Core.Player.new_missile()
    assert player1 |> Tanx.Core.Player.missile_count == 1
    :ok = game |> Tanx.Core.Game.manual_clock_tick(1000)  

    view = player1 |> Tanx.Core.Player.view_arena()
    assert view == %Tanx.Core.View.Arena{
      missiles: [
        %Tanx.Core.View.Missile{is_mine: true, name: "Kyle", x: 10.0}
      ],
      tanks: [
        %Tanx.Core.View.Tank{is_me: true, name: "Kyle"} 
      ]
    }

  end

  test "one player fires missiles too quickly", %{game: game} do 
    {:ok, player1} = game |> Tanx.Core.Game.connect(name: "Kyle")
    :ok = player1 |> Tanx.Core.Player.new_tank()
    assert :ok = player1 |> Tanx.Core.Player.new_missile()
    assert :at_limit = player1 |> Tanx.Core.Player.new_missile()    
    assert player1 |> Tanx.Core.Player.missile_count == 1

    :ok = game |> Tanx.Core.Game.manual_clock_tick(1000)  

    view = player1 |> Tanx.Core.Player.view_arena()
    assert view == %Tanx.Core.View.Arena{
      missiles: [
        %Tanx.Core.View.Missile{is_mine: true, name: "Kyle", x: 10.0},
      ],
      tanks: [
        %Tanx.Core.View.Tank{is_me: true, name: "Kyle"} 
      ]
    }

  end

  test "one player fires 2 missiles", %{game: game} do
    {:ok, player1} = game |> Tanx.Core.Game.connect(name: "Kyle")
    :ok = player1 |> Tanx.Core.Player.new_tank()
    :ok = player1 |> Tanx.Core.Player.new_missile()
    :timer.sleep(500)
    :ok = player1 |> Tanx.Core.Player.new_missile()    
    assert player1 |> Tanx.Core.Player.missile_count == 2

    :ok = game |> Tanx.Core.Game.manual_clock_tick(1000)  

    view = player1 |> Tanx.Core.Player.view_arena()
    assert view == %Tanx.Core.View.Arena{
      missiles: [
        %Tanx.Core.View.Missile{is_mine: true, name: "Kyle", x: 10.0},
        %Tanx.Core.View.Missile{is_mine: true, name: "Kyle", x: 10.0}
      ],
      tanks: [
        %Tanx.Core.View.Tank{is_me: true, name: "Kyle"} 
      ]
    }

  end

  test "one player fires a missile without tank", %{game: game} do
    {:ok, player1} = game |> Tanx.Core.Game.connect(name: "Kyle")
    assert :no_tank == player1 |> Tanx.Core.Player.new_missile()
    assert player1 |> Tanx.Core.Player.missile_count == 0
  end

  test "one player fires a too many missiles", %{game: game} do
    {:ok, player1} = game |> Tanx.Core.Game.connect(name: "Kyle")
    :ok = player1 |> Tanx.Core.Player.new_tank()
    :ok = player1 |> Tanx.Core.Player.new_missile()
    :timer.sleep(500)
    :ok = player1 |> Tanx.Core.Player.new_missile()
    :timer.sleep(500)
    :ok = player1 |> Tanx.Core.Player.new_missile()
    :timer.sleep(500)
    :ok = player1 |> Tanx.Core.Player.new_missile()
    :timer.sleep(500)
    :ok = player1 |> Tanx.Core.Player.new_missile()
   
    assert :at_limit == player1 |> Tanx.Core.Player.new_missile()     
    assert player1 |> Tanx.Core.Player.missile_count == 5

    :ok = game |> Tanx.Core.Game.manual_clock_tick(1000)  

    view = player1 |> Tanx.Core.Player.view_arena()
    assert view == %Tanx.Core.View.Arena{
      missiles: [
        %Tanx.Core.View.Missile{is_mine: true, name: "Kyle", x: 10.0},
        %Tanx.Core.View.Missile{is_mine: true, name: "Kyle", x: 10.0},
        %Tanx.Core.View.Missile{is_mine: true, name: "Kyle", x: 10.0},
        %Tanx.Core.View.Missile{is_mine: true, name: "Kyle", x: 10.0},
        %Tanx.Core.View.Missile{is_mine: true, name: "Kyle", x: 10.0}
      ],
      tanks: [
        %Tanx.Core.View.Tank{is_me: true, name: "Kyle"} 
      ]
    }
  end
end
