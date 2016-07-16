defmodule Tanx.GameChannel do
  use Tanx.Web, :channel

  require Logger


  def join("game", _auth_msg, socket) do
    Process.flag(:trap_exit, true)
    {:ok, socket}
  end


  def handle_in("join", %{"name" => player_name}, socket) do
    socket = if !socket.assigns[:player] do
      {:ok, player} = :game_core |> Tanx.Core.Game.connect(name: player_name)
      assign(socket, :player, player)
    else
      socket
    end
    {:noreply, socket}
  end


  def handle_in("leave", _msg, socket) do
    player = socket.assigns[:player]
    socket = if player do
      player |> Tanx.Core.Player.leave
      assign(socket, :player, nil)
    else
      socket
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


  def handle_in("view_structure", _msg, socket) do
    player = socket.assigns[:player]
    if player do
      view = player |> Tanx.Core.Player.view_arena_structure()
      push(socket, "view_structure", view)
    end
    {:noreply, socket}
  end


  def handle_in("view_arena", _msg, socket) do
    player = socket.assigns[:player]
    if player do
      arena_view = player |> Tanx.Core.Player.view_arena_objects()
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


  def handle_in("launch_tank", msg, socket) do
    player = socket.assigns[:player]
    if player do
      params = [armor: 2.0, max_armor: 2.0]
      params = if msg |> Dict.has_key?("entry_point") do
        params |> Keyword.put(:entry_point, msg["entry_point"])
      else
        params
      end
      player |> Tanx.Core.Player.new_tank(params)
    end
    {:noreply, socket}
  end


  def handle_in("self_destruct_tank", _msg, socket) do
    player = socket.assigns[:player]
    if player do
      player |> Tanx.Core.Player.self_destruct_tank
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


  def handle_in("heartbeat", _msg, socket) do
    {:noreply, socket}
  end


  def handle_in(msg, payload, socket) do
    Logger.error("Unknown message received on game channel: #{inspect(msg)}: #{inspect(payload)}")
    {:noreply, socket}
  end


  intercept ["view_players"]


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
    Logger.info("Connection terminated due to #{inspect(reason)}")
    player = socket.assigns[:player]
    socket = if player do
      player |> Tanx.Core.Player.leave
      assign(socket, :player, nil)
    else
      socket
    end
    {reason, socket}
  end

end
