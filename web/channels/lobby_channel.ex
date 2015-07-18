defmodule Tanx.LobbyChannel do
  use Tanx.Web, :channel

  require Logger


  def join("lobby", _auth_msg, socket) do
    {:ok, socket}
  end


  def handle_in("view_players", _msg, socket) do
    players_view = :game_core |> Tanx.Core.Game.view_players
    push(socket, "view_players", %{players: players_view})
    {:noreply, socket}
  end

  def handle_in(msg, payload, socket) do
    Logger.error("Unknown message received on lobby channel: #{inspect(msg)}: #{inspect(payload)}")
    {:noreply, socket}
  end


  def handle_out(msg, payload, socket) do
    push(socket, msg, payload)
    {:noreply, socket}
  end


end
