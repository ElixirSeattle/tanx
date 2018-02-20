defmodule Tanx.Updater.Process do

  #### Public API

  def start_link(game, arena, opts \\ []) do
    interval = Keyword.get(opts, :interval, 0.05)
    time_config = Keyword.get(opts, :time_config, nil)
    GenServer.start_link(__MODULE__, {game, arena, interval, time_config})
  end


  #### GenServer callbacks

  use GenServer

  defmodule InternalData do
    defstruct(
      decomposed_walls: []
    )
  end

  defmodule State do
    defstruct(
      game: nil,
      arena: nil,
      internal: nil,
      interval: nil,
      time_config: nil,
      last: 0.0
    )
  end

  def init({game, arena, interval, time_config}) do
    internal = %InternalData{
      decomposed_walls: Enum.map(arena.walls, &Tanx.Updater.Walls.decompose_wall/1)
    }
    state = %State{
      game: game,
      arena: arena,
      internal: internal,
      interval: interval,
      time_config: time_config,
      last: Tanx.Util.SystemTime.get(time_config)
    }
    {:ok, state, next_tick_timeout(state)}
  end

  def handle_cast(:update, state) do
    state = perform_update(state)
    {:noreply, state, next_tick_timeout(state)}
  end

  def handle_info(:timeout, state) do
    state = perform_update(state)
    {:noreply, state, next_tick_timeout(state)}
  end

  def handle_info(request, state), do: super(request, state)


  #### Logic

  @pi :math.pi()

  defp perform_update(state) do
    commands = GenServer.call(state.game, :get_commands)
    cur = Tanx.Util.SystemTime.get(state.time_config)
    {arena, internal, events} =
      Enum.reduce(commands, {state.arena, state.internal, []}, fn cmd, {a, p, e} ->
        {a, p, de} = Tanx.Updater.CommandHandler.handle(cmd, a, p, cur)
        {a, p, e ++ de}
      end)
    {arena, internal, de} = tick(arena, internal, cur - state.last)
    GenServer.call(state.game, {:update, cur, arena, events ++ de})
    %State{state | arena: arena, internal: internal, last: cur}
  end

  defp next_tick_timeout(state) do
    if state.interval == nil do
      :infinity
    else
      timeout_secs = max(state.last + state.interval - Tanx.Util.SystemTime.get(state.time_config), 0.0)
      trunc(timeout_secs * 1000)
    end
  end

  defp tick(arena, internal, elapsed) do
    moved_tanks = move_tanks(arena.tanks, arena.size, internal.decomposed_walls, elapsed)
    updated_explosions = update_explosions(arena.explosions, elapsed)
    updated_entry_points = update_entry_points(arena.entry_points, moved_tanks)
    updated_arena = %Tanx.Arena{arena |
      tanks: moved_tanks,
      explosions: updated_explosions,
      entry_points: updated_entry_points
    }
    {updated_arena, internal, []}
  end

  defp move_tanks(tanks, size, decomposed_walls, elapsed) do
    moved_tanks = Enum.reduce(tanks, %{}, fn {id, tank}, acc ->
      new_tank = move_tank(tank, elapsed, size)
      Map.put(acc, id, new_tank)
    end)
    tank_forces = Enum.reduce(moved_tanks, %{}, fn {id, tank}, acc ->
      force = force_on_tank(id, tank, decomposed_walls, moved_tanks)
      Map.put(acc, id, force)
    end)
    Enum.reduce(moved_tanks, %{}, fn {id, tank}, acc ->
      new_tank = %Tanx.Arena.Tank{tank | pos: vadd(tank.pos, tank_forces[id])}
      Map.put(acc, id, new_tank)
    end)
  end

  defp move_tank(tank, elapsed, size) do
    new_heading = tank.heading + tank.angular_velocity * elapsed
    new_heading = cond do
      new_heading > @pi -> new_heading - (2 * @pi)
      new_heading < -@pi -> new_heading + (2 * @pi)
      true -> new_heading
    end

    dist = tank.velocity * elapsed
    {x, y} = tank.pos
    {width, height} = size
    new_x = x + dist * :math.cos(new_heading)
    new_y = y + dist * :math.sin(new_heading)
    max_x = width / 2 - tank.radius
    max_y = height / 2 - tank.radius
    new_x = cond do
      new_x > max_x -> max_x
      new_x < -max_x -> -max_x
      true -> new_x
    end
    new_y = cond do
      new_y > max_y -> max_y
      new_y < -max_y -> -max_y
      true -> new_y
    end

    %Tanx.Arena.Tank{tank |
      pos: {new_x, new_y},
      heading: new_heading,
      dist: tank.dist + dist
    }
  end

  defp force_on_tank(id, tank, decomposed_walls, all_tanks) do
    wall_force = Tanx.Updater.Walls.force_from_decomposed_walls(
      decomposed_walls, tank.pos, tank.collision_radius)
    Enum.reduce(all_tanks, wall_force, fn {id2, tank2}, cur_force ->
      if id == id2 do
        cur_force
      else
        tank2_force = Tanx.Updater.Walls.force_from_point(
          tank2.pos, tank.pos, tank.collision_radius + tank2.collision_radius)
        vadd(cur_force, tank2_force)
      end
    end)
  end

  defp update_explosions(explosions, elapsed) do
    Enum.reduce(explosions, %{}, fn {id, explosion}, acc ->
      progress = explosion.progress + elapsed / explosion.length
      if progress >= 1.0 do
        acc
      else
        Map.put(acc, id, %Tanx.Arena.Explosion{explosion | progress: progress})
      end
    end)
  end

  defp update_entry_points(entry_points, tanks) do
    Enum.reduce(entry_points, %{}, fn {name, ep}, acc ->
      {epx, epy} = ep.pos
      ep_top = epy + ep.buffer_up
      ep_bottom = epy - ep.buffer_down
      ep_left = epx - ep.buffer_left
      ep_right = epx + ep.buffer_right
      available = Enum.all?(tanks, fn {_id, tank} ->
        {tx, ty} = tank.pos
        r = tank.radius
        tx + r < ep_left || tx - r > ep_right || ty + r < ep_bottom || ty - r > ep_top
      end)
      new_ep = %Tanx.Arena.EntryPoint{ep | available: available}
      Map.put(acc, name, new_ep)
    end)
  end

  defp vadd({x0, y0}, {x1, y1}), do: {x0 + x1, y0 + y1}

end
