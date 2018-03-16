defmodule Tanx do
  @moduledoc """
  Tanx keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def start_game(game_spec, name, opts \\ []) do
    Swarm.register_name(name, Tanx.Supervisor, :start_game, [name, game_spec, opts])
  end
end
