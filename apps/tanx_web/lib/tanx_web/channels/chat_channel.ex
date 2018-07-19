defmodule TanxWeb.ChatChannel do
  use Phoenix.Channel

  def join("chat:" <> name, _message, socket) do
    socket = assign(socket, :game, name)
    {:ok, socket}
  end

  def handle_in("join", %{"name" => player_name}, socket) do
    broadcast(socket, "entered", %{name: player_display_name(player_name)})
    {:noreply, socket}
  end

  def handle_in("leave", %{"name" => player_name}, socket) do
    broadcast(socket, "left", %{name: player_display_name(player_name)})
    {:noreply, socket}
  end

  def handle_in("rename", %{"old_name" => old_name, "new_name" => new_name}, socket) do
    broadcast(socket, "renamed", %{
      old_name: player_display_name(old_name),
      new_name: player_display_name(new_name)
    })

    {:noreply, socket}
  end

  def handle_in("message", %{"content" => content, "name" => name}, socket) do
    broadcast(socket, "message", %{content: content, name: player_display_name(name)})
    {:noreply, socket}
  end

  defp player_display_name(""), do: "Anonymous Coward"
  defp player_display_name(name), do: name
end
