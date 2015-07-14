defmodule Tanx.Core.Tank do

  # GenServer callbacks

  use GenServer

  defmodule State do
    defstruct player: nil, x: 0.0, y: 0.0, heading: 0.0, velocity: 0.0, angular_velocity: 0.0
  end


  def init({player, params}) do
    x = Keyword.get(params, :x, 0)
    y = Keyword.get(params, :y, 0)
    heading = Keyword.get(params, :heading, 0)
    {:ok, %State{player: player, x: x, y: y, heading: heading}}
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
    velocity = state.velocity
    new_heading = heading + state.angular_velocity * dt
    new_x = state.x + velocity * dt * :math.cos(new_heading)
    new_y = state.y + velocity * dt * :math.sin(new_heading)
    state = %State{state | x: new_x, y: new_y, heading: new_heading}
    update = %Tanx.Core.Updates.MoveTank{player: state.player,
      x: new_x, y: new_y, heading: new_heading}
    GenServer.cast(updater, {:update_reply, self, update})
    {:noreply, state}
  end

  def handle_cast(:die, state) do
    {:stop, :normal, state}
  end


end
