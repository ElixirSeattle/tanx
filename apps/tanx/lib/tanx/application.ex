defmodule Tanx.Application do
  @moduledoc """
  The Tanx Application Service.

  The tanx system business domain lives in this application.

  Exposes API to clients such as the `TanxWeb` application
  for use in channels, controllers, and elsewhere.
  """
  use Application

  def start(_type, _args) do
    Supervisor.start_link([Tanx.GameSwarm], strategy: :one_for_one)
  end
end
