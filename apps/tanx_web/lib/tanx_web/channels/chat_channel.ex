defmodule TanxWeb.ChatChannel do
  use Phoenix.Channel

  def join("chat:" <> name, _message, socket) do
    socket = assign(socket, :game, name)
    {:ok, socket}
  end

  def handle_in("join", %{"name" => player_name}, socket) do
    broadcast(socket, "entered", %{username: player_display_name(player_name)})
    {:noreply, socket}
  end

  def handle_in("leave", %{"name" => player_name}, socket) do
    broadcast(socket, "left", %{username: player_display_name(player_name)})
    {:noreply, socket}
  end

  def handle_in("message", %{"content" => content, "username" => username}, socket) do
    broadcast(socket, "message", %{content: content, username: player_display_name(username)})
    {:noreply, socket}
  end

  defp player_display_name(""), do: "Anonymous Coward"
  defp player_display_name(name), do: name
end
