defmodule Tanx.Core.Explosion do

  @radius 0.5


  # GenServer callbacks

  use GenServer

  defmodule State do
    defstruct pos: {0.0, 0.0},
              radius: 1.0,
              started: 0,
              lifetime: 1000
  end


  def init({x, y, radius, time, lifetime}) do
    state = %State{pos: {x, y}, radius: radius, started: time, lifetime: lifetime}
    {:ok, state}
  end


  def handle_cast({:update, _last_time, time, updater}, state) do
    age = (time - state.started) / state.lifetime
    update = %Tanx.Core.Updates.Explosion{pos: state.pos, radius: state.radius, age: age}
    GenServer.cast(updater, {:update_reply, self, update})
    if age < 1.0 do
      {:noreply, state}
    else
      {:stop, :normal, state}
    end
  end


  def handle_cast(:die, state) do
    {:stop, :normal, state}
  end

end
