defmodule Tanx.ChatChannel do
  use Phoenix.Channel

  def join(room, message, socket) do
    #push socket, "user:entered", %{username: message["username"]}
    {:ok, socket}
  end

  def handle_in("new:message", message, socket) do
    push socket, "new:message", %{content: message["content"], username: message["username"]}

    {:noreply, socket}
  end
end
