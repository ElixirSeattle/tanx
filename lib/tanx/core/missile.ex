defmodule Tanx.Core.Missile do 

  defmodule State do 
    defstruct player: nil, x: 0.0, y: 0.0, heading: 0.0, av: 0.0, v: 1.0 
  end

  ############
  #Missile API

  #Called by "Arena Objects" process.
  def start_link(player, params) do 
    GenServer.start_link(__MODULE__, {player, params})
  end

  #This api currently isn't used as the :update cast is called directly. 
  def update(pid, last_time, time, updater) do
    GenServer.cast(pid, {:update, last_time, time, updater})
  end

  def view(pid) do
    GenServer.call(pid, :view)
  end


  def die(pid,params) do
    GenServer.cast(pid,{:die, params})
  end

  #########################
  #GenServer Implementation

  def init({player, {x, y, a}}) do
    {:ok, %Tanx.Core.Missile.State{player: player, x: x, y: y, heading: a}}  
  end

  def handle_cast({:update, last_time, time, updater}, state) do 
    dt = max((time - last_time) / 1000, 0.0)
    a = state.heading
    v = state.v
    na = a + state.av * dt
    nx = state.x + v * dt * :math.cos(na)
    ny = state.y + v * dt * :math.sin(na)
    state = %State{state | x: nx, y: ny, heading: na}
    update = %Tanx.Core.Updates.MoveMissile{player: state.player, x: nx, y: ny, heading: na}
    GenServer.cast(updater, {:update_reply, self, update})
    {:noreply, state}
  end

  def handle_cast(:die, state) do
    {:stop, :normal, state}
  end

end
