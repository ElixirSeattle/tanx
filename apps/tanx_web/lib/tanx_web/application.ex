defmodule TanxWeb.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    endpoint = supervisor(TanxWeb.Endpoint, [])
    children =
      if Application.get_env(:tanx_web, :cluster_active) do
        topologies = [
          k8s: [
            strategy: Cluster.Strategy.Kubernetes,
            config: [
              mode: :ip,
              kubernetes_selector: "run=tanx",
              kubernetes_node_basename: "tanx",
              polling_interval: 5_000
            ]
          ]
        ]
        [{Cluster.Supervisor, [topologies, [name: TanxWeb.ClusterSupervisor]]}, endpoint]
      else
        [endpoint]
      end

    opts = [strategy: :one_for_one, name: TanxWeb.Supervisor]
    result = Supervisor.start_link(children, opts)

    Tanx.GameSwarm.add_callback(fn _ ->
      TanxWeb.Endpoint.broadcast!("lobby", "refresh", %{})
    end)

    result
  end

  def start_game(display_name) do
    game_spec = Tanx.ContinuousGame.create(maze: :standard)
    {:ok, game_id} = Tanx.GameSwarm.start_game(game_spec, display_name: display_name)

    game_proc = Tanx.GameSwarm.game_process(game_id)
    {:ok, meta} = Tanx.Game.get_meta(game_proc)

    TanxWeb.Endpoint.broadcast!("lobby", "started", meta)

    Tanx.Game.add_callback(game_proc, Tanx.ContinuousGame.PlayersChanged, :tanxweb, fn event ->
      TanxWeb.Endpoint.broadcast!("game:" <> game_id, "view_players", event)

      if Enum.empty?(event.players) do
        spawn(fn ->
          Tanx.Game.terminate(game_proc)
        end)
      else
        nil
      end
    end)

    Tanx.Game.add_callback(game_proc, Tanx.Game.Notifications.Ended, :tanxweb, fn _event ->
      TanxWeb.Endpoint.broadcast!("lobby", "ended", %{id: game_id})
    end)

    Tanx.Game.add_callback(game_proc, Tanx.Game.Notifications.Moved, :tanxweb, fn event ->
      TanxWeb.Endpoint.broadcast!("lobby", "moved", %{
        id: game_id,
        from: event.from_node,
        to: event.to_node
      })
    end)

    {:ok, meta}
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    TanxWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
