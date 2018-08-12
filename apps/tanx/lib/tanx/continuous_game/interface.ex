defmodule Tanx.ContinuousGame do
  def create(opts) do
    maze_name = Keyword.get(opts, :maze, :standard)
    %Tanx.ContinuousGame.Impl{maze: maze_name}
  end

  def view_players(game, player_handle) do
    Tanx.Game.control(game, {:view_players, player_handle})
  end

  def view_arena(game, player_handle) do
    Tanx.Game.control(game, {:view_arena, player_handle})
  end

  def view_static(game) do
    Tanx.Game.control(game, {:view_static})
  end

  def add_player(game, name \\ "(anonymous coward)") do
    Tanx.Game.control(game, {:add_player, name})
  end

  def remove_player(game, player_handle) do
    Tanx.Game.control(game, {:remove_player, player_handle})
  end

  def rename_player(game, player_handle, name) do
    Tanx.Game.control(game, {:rename_player, player_handle, name})
  end

  def start_tank(game, player_handle, entry_point_name) do
    Tanx.Game.control(game, {:start_tank, player_handle, entry_point_name})
  end

  def control_tank(game, player_handle, button, is_down) do
    Tanx.Game.control(game, {:control_tank, player_handle, button, is_down})
  end

  def destruct_tank(game, player_handle) do
    Tanx.Game.control(game, {:destruct_tank, player_handle})
  end

  def add_callback(game, type, name \\ nil, callback) do
    Tanx.Game.add_callback(game, type, name, callback)
  end

  defmodule Player do
    defstruct(
      name: "",
      joined_at: 0.0,
      kills: 0,
      deaths: 0
    )
  end

  defmodule PlayerPrivate do
    defstruct(
      player_id: nil,
      last_seen_at: 0.0,
      tank_id: nil,
      left: false,
      right: false,
      forward: false,
      backward: false,
      forward_speed: 2.0,
      backward_speed: 1.0,
      angular_speed: 2.0,
      bounce: 0,
      reload_length: 1.0,
      reloaded_at: 0.0
    )
  end

  defmodule PlayerListView do
    defstruct(
      players: %{},
      cur_player: nil
    )
  end

  defmodule StaticView do
    defstruct(
      size: {0.0, 0.0},
      walls: [],
      entry_points: []
    )
  end

  defmodule ArenaView do
    defstruct(
      entry_points: %{},
      tanks: %{},
      missiles: %{},
      explosions: %{},
      power_ups: %{},
      players: %{},
      cur_player: nil
    )
  end

  defmodule PlayersChanged do
    defstruct(players: %{})
  end
end
