defmodule TanxWeb.LobbyChannel do
  use Phoenix.Channel

  require Logger

  @interval_millis 1000

  def join("lobby", _message, socket) do
    send(self(), :after_join)

    Tanx.Cluster.add_receiver(self(), :games_changed)

    games =
      Tanx.Cluster.list_live_game_ids()
      |> Tanx.Cluster.load_game_meta()
      |> Enum.filter(& &1)
      |> Enum.sort_by(& Map.get(&1.settings, :display_name))

    Process.send_after(self(), :interval, @interval_millis)

    {:ok, assign(socket, :games, games)}
  end

  def handle_in("create", %{"name" => display_name}, socket) do
    {:ok, meta} = TanxWeb.Application.start_game(display_name)
    push(socket, "created", meta)
    {:noreply, socket}
  end

  def handle_in("delete", %{"id" => game_id}, socket) do
    Tanx.Cluster.stop_game(game_id)
    TanxWeb.Endpoint.broadcast!("lobby", "ended", {game_id})
    {:noreply, socket}
  end

  intercept(["started", "ended", "moved"])

  def handle_out("started", meta, socket) do
    games = [meta | socket.assigns[:games]]
    games = Enum.sort_by(games, & Map.get(&1.settings, :display_name))
    send_update(socket, games)
    {:noreply, assign(socket, :games, games)}
  end

  def handle_out("ended", %{id: game_id}, socket) do
    games = Enum.filter(socket.assigns[:games], &(&1.id != game_id))
    send_update(socket, games)
    {:noreply, assign(socket, :games, games)}
  end

  def handle_out("moved", %{id: game_id, to: to_node}, socket) do
    games =
      Enum.map(socket.assigns[:games], fn
        %{id: ^game_id} = game -> %Tanx.Game.Meta{game | node: to_node}
        game -> game
      end)

    send_update(socket, games)
    {:noreply, assign(socket, :games, games)}
  end

  def handle_info(:after_join, socket) do
    send_update(socket, socket.assigns[:games])
    {:noreply, socket}
  end

  # Temporary hack until I can figure out why some updates aren't getting
  # through.
  def handle_info(:interval, socket) do
    game_ids = Tanx.Cluster.list_live_game_ids() |> Enum.sort()
    old_game_ids =
      socket.assigns[:games]
      |> Enum.map(fn meta -> meta.id end)
      |> Enum.sort()
    result =
      if game_ids == old_game_ids do
        {:noreply, socket}
      else
        Logger.info("Updated game list on interval")
        handle_info({:games_changed, game_ids}, socket)
      end
    Process.send_after(self(), :interval, @interval_millis)
    result
  end

  def handle_info({:games_changed, game_ids}, socket) do
    old_games = socket.assigns[:games]
    old_game_ids = Enum.map(old_games, fn meta -> meta.id end)
    add_game_ids = game_ids -- old_game_ids
    del_game_ids = old_game_ids -- game_ids

    if Enum.empty?(add_game_ids) && Enum.empty?(del_game_ids) do
      {:noreply, socket}
    else
      add_games =
        add_game_ids
        |> Tanx.Cluster.load_game_meta()
        |> Enum.filter(& &1)

      games =
        Enum.filter(old_games, fn g -> not Enum.member?(del_game_ids, g.id) end) ++ add_games
      games = Enum.sort_by(games, & Map.get(&1.settings, :display_name))

      send_update(socket, games)
      {:noreply, assign(socket, :games, games)}
    end
  end

  defp send_update(socket, games) do
    games =
      Enum.map(games, fn meta ->
        %{i: meta.id, n: Map.get(meta.settings, :display_name), d: meta.node}
      end)

    build_id = System.get_env("TANX_BUILD_ID") || "local"
    node_name = Node.self()
    push(socket, "update", %{g: games, d: node_name, b: build_id})
  end
end
