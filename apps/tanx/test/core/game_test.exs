defmodule Tanx.GameTest do
  use ExUnit.Case

  setup do
    {:ok, game} = Tanx.Core.Game.start_link(clock_interval: nil)
    {:ok, game: game}
  end

  test "outside game view with no players", %{game: game} do
    view = game |> Tanx.Core.Game.view_players()
    assert view == []
  end

  test "outside game view with one player", %{game: game} do
    {:ok, _player1} = game |> Tanx.Core.Game.connect(name: "daniel")
    view = game |> Tanx.Core.Game.view_players()
    assert view == [%Tanx.Core.View.Player{is_me: false, name: "daniel"}]
  end

  test "outside game view with two players", %{game: game} do
    {:ok, _player1} = game |> Tanx.Core.Game.connect(name: "daniel")
    {:ok, _player2} = game |> Tanx.Core.Game.connect(name: "greg")
    got = game |> Tanx.Core.Game.view_players() |> Enum.into(MapSet.new)
    want = [
      %Tanx.Core.View.Player{is_me: false, name: "greg"},
      %Tanx.Core.View.Player{is_me: false, name: "daniel"}
    ] |> Enum.into(MapSet.new)
    assert got == want
  end

  test "inside game view with one player", %{game: game} do
    {:ok, player1} = game |> Tanx.Core.Game.connect(name: "daniel")
    view = player1 |> Tanx.Core.Player.view_players()
    assert view == [%Tanx.Core.View.Player{is_me: true, name: "daniel"}]
  end

  test "inside game view with two players", %{game: game} do
    {:ok, player1} = game |> Tanx.Core.Game.connect(name: "daniel")
    {:ok, _player2} = game |> Tanx.Core.Game.connect(name: "greg")
    got = player1 |> Tanx.Core.Player.view_players() |> Enum.into(MapSet.new)
    want = [
      %Tanx.Core.View.Player{is_me: false, name: "greg"},
      %Tanx.Core.View.Player{is_me: true, name: "daniel"}
    ] |> Enum.into(MapSet.new)
    assert got == want
  end

  test "outside game view after a player leaves", %{game: game} do
    {:ok, player1} = game |> Tanx.Core.Game.connect(name: "daniel")
    {:ok, _player2} = game |> Tanx.Core.Game.connect(name: "greg")
    player1 |> Tanx.Core.Player.leave()
    view = game |> Tanx.Core.Game.view_players()
    assert view == [%Tanx.Core.View.Player{is_me: false, name: "greg"}]
  end

end
