defmodule TanxWeb.JsonData do
  defmodule Player do
    @derive [Poison.Encoder]
    defstruct(
      n: "",
      me: false,
      j: 0,
      k: 0,
      d: 0
    )
  end

  defmodule Structure do
    @derive [Poison.Encoder]
    defstruct(
      h: 20.0,
      w: 20.0,
      wa: [],
      epr: 0.5,
      ep: []
    )
  end

  defmodule EntryPoint do
    @derive [Poison.Encoder]
    defstruct(
      n: "",
      x: 0.0,
      y: 0.0
    )
  end

  defmodule Arena do
    @derive [Poison.Encoder]
    defstruct(
      t: [],
      m: [],
      e: [],
      p: [],
      epa: %{}
    )
  end

  defmodule Tank do
    @derive [Poison.Encoder]
    defstruct(
      me: false,
      n: "",
      x: 0.0,
      y: 0.0,
      h: 0.0,
      r: 0.5,
      a: 0.0,
      ma: 1.0,
      t: 0.0
    )
  end

  defmodule Missile do
    @derive [Poison.Encoder]
    defstruct(
      me: false,
      x: 0.0,
      y: 0.0,
      h: 0.0
    )
  end

  defmodule Explosion do
    @derive [Poison.Encoder]
    defstruct(
      x: 0.0,
      y: 0.0,
      r: 1.0,
      a: 0.0,
      s: nil
    )
  end

  defmodule PowerUp do
    @derive [Poison.Encoder]
    defstruct(
      x: 0.0,
      y: 0.0,
      r: 0.5,
      t: nil,
      e: 0.0
    )
  end

  def format_players({:error, _}) do
    %{}
  end

  def format_players({:ok, player_list_view}) do
    cur_player_id =
      case player_list_view.cur_player do
        nil -> nil
        player_private -> player_private.player_id
      end

    players_json =
      player_list_view.players
      |> Enum.map(fn {id, player} ->
        %TanxWeb.JsonData.Player{
          n: player.name,
          me: id == cur_player_id,
          j: player.joined_at,
          k: player.kills,
          d: player.deaths
        }
      end)
      |> Enum.sort(&(&1.j < &2.j))

    %{p: players_json}
  end

  def format_structure({:error, _}) do
    %{}
  end

  def format_structure({:ok, static_view}) do
    {w, h} = static_view.size

    entry_points =
      Enum.map(static_view.entry_points, fn {name, ep} ->
        {x, y} = ep.pos

        %TanxWeb.JsonData.EntryPoint{
          n: name,
          x: x,
          y: y
        }
      end)

    walls =
      Enum.map(static_view.walls, fn wall ->
        Enum.flat_map(wall, &Tuple.to_list/1)
      end)

    %TanxWeb.JsonData.Structure{
      h: h,
      w: w,
      wa: walls,
      ep: entry_points
    }
  end

  def format_arena({:error, _}) do
    %{}
  end

  def format_arena({:ok, arena_view}) do
    cur_player_tank_id =
      case arena_view.cur_player do
        nil -> nil
        player_private -> player_private.tank_id
      end

    tanks = format_tanks(arena_view.tanks, arena_view.players, cur_player_tank_id)
    explosions = format_explosions(arena_view.explosions)
    missiles = format_missiles(arena_view.missiles)
    power_ups = format_power_ups(arena_view.power_ups)

    epa =
      Enum.reduce(arena_view.entry_points, %{}, fn {n, ep}, acc ->
        Map.put(acc, n, ep.available)
      end)

    %TanxWeb.JsonData.Arena{
      t: tanks,
      e: explosions,
      m: missiles,
      p: power_ups,
      epa: epa
    }
  end

  defp format_tanks(tanks, players, cur_player_tank_id) do
    Enum.map(tanks, fn {id, t} ->
      player_id = t.data[:player_id]
      player_name = players[player_id].name
      {x, y} = t.pos
      tread = t.dist / 2

      %TanxWeb.JsonData.Tank{
        me: id == cur_player_tank_id,
        n: player_name,
        x: truncate(x),
        y: truncate(y),
        h: truncate(t.heading),
        r: truncate(t.radius),
        a: truncate(t.armor),
        ma: truncate(t.max_armor),
        t: truncate(tread - Float.floor(tread))
      }
    end)
  end

  defp format_explosions(explosions) do
    Enum.map(explosions, fn {_id, e} ->
      {x, y} = e.pos

      %TanxWeb.JsonData.Explosion{
        x: truncate(x),
        y: truncate(y),
        r: truncate(e.radius),
        a: truncate(e.progress)
      }
    end)
  end

  defp format_missiles(missiles) do
    Enum.map(missiles, fn {_id, m} ->
      {x, y} = m.pos

      %TanxWeb.JsonData.Missile{
        x: truncate(x),
        y: truncate(y),
        h: truncate(m.heading)
      }
    end)
  end

  defp format_power_ups(power_ups) do
    Enum.map(power_ups, fn {_id, p} ->
      {x, y} = p.pos

      %TanxWeb.JsonData.PowerUp{
        x: truncate(x),
        y: truncate(y),
        r: truncate(p.radius),
        t: p.data[:type],
        e: truncate(p.expires_in)
      }
    end)
  end

  defp truncate(value) do
    round(value * 100) / 100
  end
end
