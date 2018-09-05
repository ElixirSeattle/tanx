defmodule TanxWeb.Application do
  use Application

  require Logger

  def start(_type, _args) do
    endpoint = {TanxWeb.Endpoint, []}

    children =
      if Application.get_env(:tanx_web, :cluster_active) do
        topologies = [
          k8s: [
            strategy: Cluster.Strategy.Kubernetes,
            connect: {__MODULE__, :connect_node, []},
            disconnect: {__MODULE__, :disconnect_node, []},
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

    Supervisor.start_link(children, strategy: :one_for_one, name: TanxWeb.Supervisor)
  end

  def start_game(display_name) do
    game_spec = Tanx.ContinuousGame.create(maze: :standard)
    {:ok, game_id, game_pid} = Tanx.Cluster.start_game(game_spec, display_name: display_name)
    {:ok, meta} = Tanx.Game.get_meta(game_pid)

    TanxWeb.Endpoint.broadcast!("lobby", "started", meta)

    Tanx.Game.add_callback(game_pid, Tanx.ContinuousGame.PlayersChanged, :tanxweb, fn event ->
      spawn(fn ->
        TanxWeb.Endpoint.broadcast!("game:" <> game_id, "view_players", event)
      end)

      if Enum.empty?(event.players) do
        spawn(fn ->
          Tanx.Cluster.stop_game(game_id)
        end)
      else
        nil
      end
    end)

    Tanx.Game.add_callback(game_pid, Tanx.Game.Notifications.Ended, :tanxweb, fn _event ->
      spawn(fn ->
        TanxWeb.Endpoint.broadcast!("lobby", "ended", %{id: game_id})
      end)
    end)

    Tanx.Game.add_callback(game_pid, Tanx.Game.Notifications.Moved, :tanxweb, fn event ->
      spawn(fn ->
        TanxWeb.Endpoint.broadcast!("lobby", "moved", %{
          id: game_id,
          from: event.from_node,
          to: event.to_node
        })
      end)
    end)

    {:ok, meta}
  end

  def connect_node(node) do
    :net_kernel.connect_node(node)
    Tanx.Cluster.connect_node(node)
    Logger.info("**** Connected #{inspect(node())} to #{inspect(node)}")
    true
  end

  def disconnect_node(node) do
    Logger.info("**** Disconnected #{inspect(node())} from #{inspect(node)}")
    true
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    TanxWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
