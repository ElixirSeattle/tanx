  defmodule Tanx.Core.Tank do


  # GenServer callbacks


  use GenServer

  defmodule State do
    defstruct structure: nil,
              player: nil,
              x: 0.0,
              y: 0.0,
              heading: 0.0,
              velocity: 0.0,
              angular_velocity: 0.0
  end

  @tank_radius 0.5

  def init({player, structure, params}) do
    x = Keyword.get(params, :x, 0)
    y = Keyword.get(params, :y, 0)
    heading = Keyword.get(params, :heading, 0)
    {:ok, %State{structure: structure, player: player, x: x, y: y, heading: heading}}
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

    heading = state.heading
    new_heading = heading + state.angular_velocity * dt
    pi = :math.pi()
    new_heading = cond do
      new_heading > pi -> new_heading - (2 * pi)
      new_heading < -pi -> new_heading + (2 * pi)
      true -> new_heading
    end

    velocity = state.velocity
    new_x = state.x + velocity * dt * :math.cos(new_heading)
    new_y = state.y + velocity * dt * :math.sin(new_heading)
    max_x = state.structure.width / 2 - @tank_radius
    max_y = state.structure.height / 2 - @tank_radius
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

    state = %State{state | x: new_x, y: new_y, heading: new_heading}
    update = %Tanx.Core.Updates.MoveTank{player: state.player,
      x: new_x, y: new_y, heading: new_heading, radius: @tank_radius}

    GenServer.cast(updater, {:update_reply, self, update})
    {:noreply, state}
  end

  def handle_cast(:die, state) do
    {:stop, :normal, state}
  end


end
