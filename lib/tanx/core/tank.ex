  defmodule Tanx.Core.Tank do


  # GenServer callbacks


  use GenServer

  defmodule State do
    defstruct arena_width: 20.0,
              arena_height: 20.0,
              decomposed_walls: [],
              player: nil,
              x: 0.0,
              y: 0.0,
              heading: 0.0,
              velocity: 0.0,
              angular_velocity: 0.0
  end

  @tank_radius 0.5
  @tank_wall_buffer 0.1

  def init({arena_width, arena_height, decomposed_walls, player, params}) do
    x = Keyword.get(params, :x, 0)
    y = Keyword.get(params, :y, 0)
    heading = Keyword.get(params, :heading, 0)
    state = %State{arena_width: arena_width, arena_height: arena_height,
      decomposed_walls: decomposed_walls,
      player: player, x: x, y: y, heading: heading}
    {:ok, state}
  end

  def handle_call(:tank, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:control_movement, velocity, angular_velocity}, _from, state) do
    {:reply, :ok, %State{state | velocity: velocity || state.velocity,
      angular_velocity: angular_velocity || state.angular_velocity}}
  end

  def handle_call(:ping, _from, state) do
    {:reply, :ok, state}
  end


  def handle_cast({:update, last_time, time, updater}, state) do
    dt = max((time - last_time) / 1000, 0.0)

    new_heading = _new_heading(state, dt)
    {new_x, new_y} = _new_pos(state, new_heading, dt)
    {new_x, new_y} = _check_walls(new_x, new_y, state.decomposed_walls)

    state = %State{state | x: new_x, y: new_y, heading: new_heading}
    update = %Tanx.Core.Updates.MoveTank{player: state.player,
      x: new_x, y: new_y, heading: new_heading, radius: @tank_radius}

    GenServer.cast(updater, {:update_reply, self, update})
    {:noreply, state}
  end

  def handle_cast(:die, state) do
    {:stop, :normal, state}
  end


  defp _new_heading(state, dt) do
    new_heading = state.heading + state.angular_velocity * dt
    pi = :math.pi()
    cond do
      new_heading > pi -> new_heading - (2 * pi)
      new_heading < -pi -> new_heading + (2 * pi)
      true -> new_heading
    end
  end

  defp _new_pos(state, new_heading, dt) do
    dist = state.velocity * dt
    new_x = state.x + dist * :math.cos(new_heading)
    new_y = state.y + dist * :math.sin(new_heading)
    max_x = state.arena_width / 2 - @tank_radius
    max_y = state.arena_height / 2 - @tank_radius
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
    {new_x, new_y}
  end

  defp _check_walls(x, y, decomposed_walls) do
    {fx, fy} = Tanx.Core.Obstacles.force_from_decomposed_walls(
      decomposed_walls, {x, y}, @tank_radius + @tank_wall_buffer)
    {x + fx, y + fy}
  end

end
