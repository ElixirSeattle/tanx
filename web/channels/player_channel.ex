defmodule Tanx.PlayerChannel do
  use Tanx.Web, :channel

  require Logger


  def join("player", auth_msg, socket) do
    player_name = auth_msg["name"]
    {:ok, player} = :game_core |> Tanx.Core.Game.connect(name: player_name)
    socket = assign(socket, :player, player)
    {:ok, socket}
  end


  def handle_in("view_players", _msg, socket) do
    player = socket.assigns[:player]
    players_view = player |> Tanx.Core.Player.view_players()
    push(socket, "view_players", %{players: players_view})
    {:noreply, socket}
  end

  def handle_in("view_arena", _msg, socket) do
    player = socket.assigns[:player]
    arena_view = player |> Tanx.Core.Player.view_arena()
    push(socket, "view_arena", arena_view)
    {:noreply, socket}
  end

  def handle_in("rename", %{"name" => name}, socket) do
    player = socket.assigns[:player]
    :ok = player |> Tanx.Core.Player.rename(name)
    {:noreply, socket}
  end

  def handle_in(msg, payload, socket) do
    Logger.error("Unknown message received on player channel: #{inspect(msg)}: #{inspect(payload)}")
    {:noreply, socket}
  end


  def handle_out("view_players", _, socket) do
    player = socket.assigns[:player]
    players_view = player |> Tanx.Core.Player.view_players()
    push(socket, "view_players", %{players: players_view})
    {:noreply, socket}
  end

  def handle_out(msg, payload, socket) do
    push(socket, msg, payload)
    {:noreply, socket}
  end


  def terminate(reason, socket) do
    socket.assigns[:player] |> Tanx.Core.Player.leave
    {reason, socket}
  end

end
