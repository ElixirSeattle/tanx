defmodule TanxWeb.LobbyChannel do
  use Phoenix.Channel

  def join("lobby", _message, socket) do
    send(self(), :after_join)
    {:ok, load_all_games(socket)}
  end

  def handle_in("create", %{"name" => display_name}, socket) do
    {:ok, meta} = TanxWeb.Application.start_game(display_name)
    push(socket, "created", meta)
    {:noreply, socket}
  end

  def handle_in("delete", %{"id" => game_id}, socket) do
    Tanx.Game.terminate({:via, :swarm, game_id})
    TanxWeb.Endpoint.broadcast!("lobby", "ended", {game_id})
    {:noreply, socket}
  end

  intercept(["started", "ended"])

  def handle_out("started", meta, socket) do
    games = [meta | socket.assigns[:games]]
    games = Enum.sort_by(games, &(&1.display_name))
    send_update(socket, games)
    {:noreply, assign(socket, :games, games)}
  end

  def handle_out("ended", %{id: game_id}, socket) do
    games = Enum.filter(socket.assigns[:games], &(&1.id != game_id))
    send_update(socket, games)
    {:noreply, assign(socket, :games, games)}
  end

  def handle_info(:after_join, socket) do
    send_update(socket, socket.assigns[:games])
    {:noreply, socket}
  end

  defp load_all_games(socket) do
    games = Enum.sort_by(Tanx.GameSwarm.list_games(), &(&1.display_name))
    assign(socket, :games, games)
  end

  defp send_update(socket, games) do
    games = Enum.map(games, fn meta ->
      %{i: meta.id, n: meta.display_name, d: meta.node}
    end)
    push(socket, "update", %{g: games, d: Node.self()})
  end
end
