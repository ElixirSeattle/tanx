defmodule TanxWeb.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    game_spec = Tanx.ContinuousGame.create(maze: :standard)
    Tanx.start_game(game_spec, "game1")

    Tanx.Game.add_callback("game1", Tanx.ContinuousGame.PlayersChanged, :tanxweb, fn event ->
      TanxWeb.Endpoint.broadcast!("game:game1", "view_players", event)
    end)

    # Define workers and child supervisors to be supervised
    children = [
      # Start the endpoint when the application starts
      supervisor(TanxWeb.Endpoint, [])
      # Start your own worker by calling: TanxWeb.Worker.start_link(arg1, arg2, arg3)
      # worker(TanxWeb.Worker, [arg1, arg2, arg3]),
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TanxWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    TanxWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
