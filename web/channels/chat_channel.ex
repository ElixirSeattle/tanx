defmodule Tanx.ChatChannel do
  use Phoenix.Channel

  def join(room, message, socket) do
    send self, { :after_join, message }
    { :ok, socket }
  end

  def handle_info({:after_join, message}, socket) do
    broadcast socket, "user:entered", %{ username: message["name"] || "Anonymous Coward" }
    { :noreply, socket }
  end

  def handle_in("new:message", message, socket) do
    broadcast socket, "new:message", %{content: message["content"], username: message["username"]}

    {:noreply, socket}
  end
end
