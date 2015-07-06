defmodule Tanx.BasicPlayerTest do
  use ExUnit.Case

  setup do
    {:ok, game} = Tanx.Core.Game.start_link(clock_interval: -1)
    {:ok, game: game}
  end

  test "outside game view with no players", %{game: game} do
    {:ok, view} = game |> Tanx.Core.Game.view()
    assert view == %Tanx.Core.View{}
  end

  test "outside game view with one player", %{game: game} do
    {:ok, _player1} = game |> Tanx.Core.Game.connect(name: "daniel")
    {:ok, view} = game |> Tanx.Core.Game.view()
    assert view == %Tanx.Core.View{other_players: [%Tanx.Core.View.Player{name: "daniel"}]}
  end

  test "inside game view with one player but no tank", %{game: game} do
    {:ok, player1} = game |> Tanx.Core.Game.connect(name: "daniel")
    {:ok, view} = player1 |> Tanx.Core.Player.view()
    assert view == %Tanx.Core.View{my_player: %Tanx.Core.View.Player{name: "daniel"},
      arena: %Tanx.Core.View.Arena{}}
  end

  test "inside game view with two players but no tank", %{game: game} do
    {:ok, player1} = game |> Tanx.Core.Game.connect(name: "daniel")
    {:ok, _player2} = game |> Tanx.Core.Game.connect(name: "greg")
    {:ok, view} = player1 |> Tanx.Core.Player.view()
    assert view == %Tanx.Core.View{my_player: %Tanx.Core.View.Player{name: "daniel"},
      other_players: [%Tanx.Core.View.Player{name: "greg"}],
      arena: %Tanx.Core.View.Arena{}}
  end

  test "inside game view with one player and a tank", %{game: game} do
    {:ok, player1} = game |> Tanx.Core.Game.connect(name: "daniel")
    :ok = player1 |> Tanx.Core.Player.new_tank()
    {:ok, view} = player1 |> Tanx.Core.Player.view()
    assert view == %Tanx.Core.View{my_player: %Tanx.Core.View.Player{name: "daniel"},
      arena: %Tanx.Core.View.Arena{my_tank: %Tanx.Core.View.Tank{}}}
  end

  test "inside game view with two players and tanks", %{game: game} do
    {:ok, player1} = game |> Tanx.Core.Game.connect(name: "daniel")
    {:ok, player2} = game |> Tanx.Core.Game.connect(name: "greg")
    :ok = player1 |> Tanx.Core.Player.new_tank()
    :ok = player2 |> Tanx.Core.Player.new_tank()
    {:ok, view} = player1 |> Tanx.Core.Player.view()
    assert view == %Tanx.Core.View{my_player: %Tanx.Core.View.Player{name: "daniel"},
      other_players: [%Tanx.Core.View.Player{name: "greg"}],
      arena: %Tanx.Core.View.Arena{my_tank: %Tanx.Core.View.Tank{}, objects: [%Tanx.Core.View.Tank{}]}}
  end

  test "adding and deleting tanks", %{game: game} do
    {:ok, player1} = game |> Tanx.Core.Game.connect(name: "daniel")
    :ok = player1 |> Tanx.Core.Player.new_tank()
    :already_present = player1 |> Tanx.Core.Player.new_tank()
    :ok = player1 |> Tanx.Core.Player.destroy_tank()
    :not_present = player1 |> Tanx.Core.Player.destroy_tank()
    {:ok, view} = player1 |> Tanx.Core.Player.view()
    assert view == %Tanx.Core.View{my_player: %Tanx.Core.View.Player{name: "daniel"},
      arena: %Tanx.Core.View.Arena{}}
  end

  test "disconnecting players", %{game: game} do
    {:ok, player1} = game |> Tanx.Core.Game.connect(name: "daniel")
    {:ok, player2} = game |> Tanx.Core.Game.connect(name: "greg")
    :ok = player2 |> Tanx.Core.Player.new_tank()
    :ok = player2 |> Tanx.Core.Player.disconnect()
    {:ok, view} = player1 |> Tanx.Core.Player.view()
    assert view == %Tanx.Core.View{my_player: %Tanx.Core.View.Player{name: "daniel"},
      arena: %Tanx.Core.View.Arena{}}
  end

end
