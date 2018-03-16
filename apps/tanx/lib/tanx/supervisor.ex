defmodule Tanx.Supervisor do
  @moduledoc """
  The Tanx game supervisor.
  """
  use DynamicSupervisor

  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_game(name, game_spec, opts \\ []) do
    start_mfa = {Tanx.Game, :start_link, [game_spec, opts]}
    child_spec = %{id: name, start: start_mfa, restart: :temporary}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
