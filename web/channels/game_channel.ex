defmodule Tanx.GameChannel do
  use Tanx.Web, :channel

  require Logger


  def join("game", _auth_msg, socket) do
    {:ok, socket}
  end


  def handle_in("join", %{"name" => player_name}, socket) do
    if !socket.assigns[:player] do
      {:ok, player} = :game_core |> Tanx.Core.Game.connect(name: player_name)
      socket = assign(socket, :player, player)
    end
    {:noreply, socket}
  end

  def handle_in("leave", _msg, socket) do
    player = socket.assigns[:player]
    if player do
      player |> Tanx.Core.Player.leave
      socket = assign(socket, :player, nil)
    end
    {:noreply, socket}
  end

  def handle_in("view_players", _msg, socket) do
    player = socket.assigns[:player]
    players_view = if player do
      player |> Tanx.Core.Player.view_players()
    else
      :game_core |> Tanx.Core.Game.view_players()
    end
    push(socket, "view_players", %{players: players_view})
    {:noreply, socket}
  end

  def handle_in("view_arena", _msg, socket) do
    player = socket.assigns[:player]
    if player do
      arena_view = player |> Tanx.Core.Player.view_arena()
      push(socket, "view_arena", arena_view)
    end
    {:noreply, socket}
  end

  def handle_in("rename", %{"name" => name}, socket) do
    player = socket.assigns[:player]
    if player do
      :ok = player |> Tanx.Core.Player.rename(name)
    end
    {:noreply, socket}
  end

  def handle_in("launch_tank", _msg, socket) do
    player = socket.assigns[:player]
    if player do
      player |> Tanx.Core.Player.new_tank
    end
    {:noreply, socket}
  end

  def handle_in("remove_tank", _msg, socket) do
    player = socket.assigns[:player]
    if player do
      player |> Tanx.Core.Player.remove_tank
    end
    {:noreply, socket}
  end

  def handle_in("control_tank", %{"button" => button, "down" => down}, socket) do
    player = socket.assigns[:player]
    if player do
      player |> Tanx.Core.Player.control_tank(button, down)
    end
    {:noreply, socket}
  end

  def handle_in(msg, payload, socket) do
    Logger.error("Unknown message received on game channel: #{inspect(msg)}: #{inspect(payload)}")
    {:noreply, socket}
  end


  def handle_out("view_players", original_view, socket) do
    player = socket.assigns[:player]
    if player do
      players_view = player |> Tanx.Core.Player.view_players()
      push(socket, "view_players", %{players: players_view})
    else
      push(socket, "view_players", original_view)
    end
    {:noreply, socket}
  end

  def handle_out(msg, payload, socket) do
    push(socket, msg, payload)
    {:noreply, socket}
  end


  def terminate(reason, socket) do
    player = socket.assigns[:player]
    if player do
      player |> Tanx.Core.Player.leave
      socket = assign(socket, :player, nil)
    end
    {reason, socket}
  end

end
