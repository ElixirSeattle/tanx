defmodule Tanx.GameSwarm do
  @games_group :games

  def start_game(game_spec, opts \\ []) do
    registered = Swarm.registered() |> Enum.map(fn {id, _pid} -> id end)
    game_id = Tanx.Util.ID.create("G", registered, 8)
    opts_with_game_id = Keyword.put(opts, :game_id, game_id)
    case Swarm.register_name(game_id, Tanx.Game, :start, [game_spec, opts_with_game_id]) do
      {:error, {:already_registered, _pid}} ->
        start_game(game_spec, opts)
      {:error, other_reason} ->
        {:error, other_reason}
      {:ok, pid} ->
        Swarm.join(@games_group, pid)
        {:ok, game_id}
    end
  end

  def list_games() do
    @games_group
    |> Swarm.multi_call({:meta}, 1000)
    |> Enum.map(fn
      {:ok, meta} -> meta
      {:error, _} -> nil
    end)
    |> Enum.filter(&(&1 != nil))
  end
end
