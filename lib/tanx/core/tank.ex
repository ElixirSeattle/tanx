defmodule Tanx.Core.Tank do

  # GenServer callbacks

  use GenServer

  defmodule State do
    defstruct player: nil, x: 0.0, y: 0.0, a: 0.0, v: 0.0, av: 0.0
  end


  def init({player, params}) do
    x = Keyword.get(params, :x, 0)
    y = Keyword.get(params, :y, 0)
    a = Keyword.get(params, :a, 0)
    {:ok, %State{player: player, x: x, y: y, a: a}}
  end


  def handle_call({:control_movement, v, av}, _from, state) do
    {:reply, :ok, %State{state | v: v || state.v, av: av || state.av}}
  end

  def handle_call(:ping, _from, state) do
    {:reply, :ok, state}
  end


  def handle_cast({:update, last_time, time, updater}, state) do
    dt = max((time - last_time) / 1000, 0.0)
    a = state.a
    v = state.v
    na = a + state.av * dt
    nx = state.x + v * dt * :math.cos(a)
    ny = state.y + v * dt * :math.sin(a)
    state = %State{state | x: nx, y: ny, a: na}
    update = %Tanx.Core.Updates.MoveTank{player: state.player, x: nx, y: ny, a: na}
    GenServer.cast(updater, {:update_reply, self, update})
    {:noreply, state}
  end

  def handle_cast(:die, state) do
    {:stop, :normal, state}
  end


end
