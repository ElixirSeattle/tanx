defmodule TanxWeb.GameChannel do
  use TanxWeb, :channel

  require Logger


  def join("game", _auth_msg, socket) do
    Process.flag(:trap_exit, true)
    {:ok, socket}
  end


  def handle_in("join", %{"name" => player_name}, socket) do
    socket =
      if !socket.assigns[:player] do
        {:ok, player} = Tanx.ContinuousGame.add_player(:game_core, player_name)
        assign(socket, :player, player)
      else
        socket
      end
    {:noreply, socket}
  end


  def handle_in("leave", _msg, socket) do
    socket =
      case socket.assigns[:player] do
        nil -> socket
        player ->
          Tanx.ContinuousGame.remove_player(:game_core, player)
          assign(socket, :player, nil)
      end
    {:noreply, socket}
  end


  def handle_in("view_players", _msg, socket) do
    view =
      :game_core
      |> Tanx.ContinuousGame.view_players(socket.assigns[:player])
      |> TanxWeb.JsonData.format_players
    push(socket, "view_players", view)
    {:noreply, socket}
  end


  def handle_in("view_structure", _msg, socket) do
    view =
      :game_core
      |> Tanx.ContinuousGame.view_static
      |> TanxWeb.JsonData.format_structure
    push(socket, "view_structure", view)
    {:noreply, socket}
  end


  def handle_in("view_arena", _msg, socket) do
    view =
      :game_core
      |> Tanx.ContinuousGame.view_arena(socket.assigns[:player])
      |> TanxWeb.JsonData.format_arena
    push(socket, "view_arena", view)
    {:noreply, socket}
  end


  def handle_in("rename", %{"name" => name}, socket) do
    player = socket.assigns[:player]
    if player do
      Tanx.ContinuousGame.rename_player(:game_core, player, name)
    end
    {:noreply, socket}
  end


  def handle_in("launch_tank", %{"entry_point" => entry_point}, socket) do
    player = socket.assigns[:player]
    if player do
      Tanx.ContinuousGame.start_tank(:game_core, player, entry_point)
    end
    {:noreply, socket}
  end


  def handle_in("self_destruct_tank", _msg, socket) do
    player = socket.assigns[:player]
    if player do
      Tanx.ContinuousGame.destruct_tank(:game_core, player)
    end
    {:noreply, socket}
  end


  def handle_in("control_tank", %{"button" => button, "down" => down}, socket)
      when button == "left" or button == "right" or button == "backward" or button == "forward" or button == "fire" do
    player = socket.assigns[:player]
    if player do
      Tanx.ContinuousGame.control_tank(:game_core, player, String.to_atom(button), down)
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


  def handle_out("view_players", _event, socket) do
    view =
      :game_core
      |> Tanx.ContinuousGame.view_players(socket.assigns[:player])
      |> TanxWeb.JsonData.format_players
    push(socket, "view_players", view)
    {:noreply, socket}
  end

  def handle_out(msg, payload, socket) do
    push(socket, msg, payload)
    {:noreply, socket}
  end


  def terminate(reason, socket) do
    Logger.info("Connection terminated due to #{inspect(reason)}")
    socket =
      case socket.assigns[:player] do
        nil -> socket
        player ->
          Tanx.ContinuousGame.remove_player(:game_core, player)
          assign(socket, :player, nil)
      end
    {reason, socket}
  end

end
