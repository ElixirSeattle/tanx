defmodule Tanx.Application do
  @moduledoc """
  The Tanx Application Service.

  The tanx system business domain lives in this application.

  Exposes API to clients such as the `TanxWeb` application
  for use in channels, controllers, and elsewhere.
  """
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    impl = Tanx.ContinuousGame.create(maze: :standard)

    Supervisor.start_link(
      [
        worker(Tanx.Game, [impl, [name: :game_core]])
      ],
      strategy: :one_for_one,
      name: Tanx.Supervisor
    )
  end
end
