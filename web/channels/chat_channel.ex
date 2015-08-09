defmodule Tanx.ChatChannel do
  use Phoenix.Channel

  def join(room, message, socket) do
    { :ok, socket }
  end

  def handle_in("join", %{"name" => ""}, socket) do
    broadcast socket, "user:entered", %{ username: "Anonymous Coward" }
    { :noreply, socket }
  end

  def handle_in("join", %{"name" => player_name}, socket) do
    broadcast socket, "user:entered", %{ username: player_name }
    { :noreply, socket }
  end

  def handle_in("leave", %{"name" => ""}, socket) do
    broadcast socket, "user:left", %{ username: "Anonymous Coward" }
    { :noreply, socket }
  end

  def handle_in("leave", %{"name" => player_name}, socket) do
    broadcast socket, "user:left", %{ username: player_name }
    { :noreply, socket }
  end

  def handle_in("new:message", %{"content" => content, "username" => ""}, socket) do
    broadcast socket, "new:message", %{ content: content, username: "Anonymous Coward" }
    {:noreply, socket}
  end

  def handle_in("new:message", %{"content" => content, "username" => username}, socket) do
    broadcast socket, "new:message", %{ content: content, username: username }
    {:noreply, socket}
  end
end
