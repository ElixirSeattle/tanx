defmodule TanxWeb.PageController do
  use TanxWeb, :controller

  def index(conn, _params) do
    build_id = System.get_env("TANX_BUILD_ID") || "local"

    conn
    |> assign(:build_id, build_id)
    |> render("index.html")
  end

  def stats(conn, _params) do
    {game_count, player_count} =
      Tanx.Cluster.list_live_game_ids()
      |> Tanx.Cluster.load_game_meta()
      |> Enum.reduce({0, 0}, fn
        nil, {gc, pc} -> {gc, pc}
        meta, {gc, pc} -> {gc + 1, pc + Map.get(meta.stats, :player_count, 0)}
      end)
    text(conn, "games: #{inspect(game_count)}, players: #{inspect(player_count)}")
  end
end
