defmodule Tanx.Core.Missile do

  defmodule State do
    defstruct arena_width: 20.0,
              arena_height: 20.0,
              decomposed_walls: [],
              player: nil,
              x: 0.0,
              y: 0.0,
              heading: 0.0,
              v: 10.0,
              explosion: nil

  end

  @explosion_radius 1.0
  @explosion_time 0.6

  ############
  #Missile API

  #Called by "Arena Objects" process.
  def start_link(player, arena_width, arena_height, decomposed_walls, x, y, a) do
    GenServer.start_link(__MODULE__, {player, arena_width, arena_height, decomposed_walls, x, y, a})
  end

  #This api currently isn't used as the :update cast is called directly.
  def update(pid, last_time, time, updater) do
    GenServer.cast(pid, {:update, last_time, time, updater})
  end

  def explode(pid) do
    GenServer.cast(pid, :explode)
  end

  #########################
  #GenServer Implementation

  use GenServer

  def init({player, arena_width, arena_height, decomposed_walls, x, y, a}) do
    {:ok, %Tanx.Core.Missile.State{arena_width: arena_width, 
                                  arena_height: arena_height, 
                                  decomposed_walls: decomposed_walls, 
                                  player: player, 
                                  x: x, 
                                  y: y, 
                                  heading: a}}
  end

  def handle_cast({:update, last_time, time, updater}, state) do
    dt = max((time - last_time) / 1000, 0.0)
    if state.explosion == nil do
      update_missile(updater, dt, state)
    else
      update_explosion(updater, dt, state)
    end
  end


  def handle_cast(:explode, _from, state) do
    if state.explosion == nil do
      state = %State{state | explosion: 0.0}
    end
    {:noreply, state}
  end

  ##############################
  # Helper Functions

  def update_missile(updater, dt, state) do
    a = state.heading
    v = state.v
    nx = state.x + v * dt * :math.cos(a)
    ny = state.y + v * dt * :math.sin(a)
    if _hit_obstacle?(nx, ny, state) != nil or 
       _hit_arena_edge?(nx, ny, state) do 
      IO.puts "Exploding misile"
      state = %State{state | explosion: 0.0}
    end
      
    update = %Tanx.Core.Updates.MoveMissile{player: state.player, x: nx, y: ny, heading: a}
    state = %State{state | x: nx, y: ny}
    updater |> Tanx.Core.ArenaUpdater.send_update_reply(update)
    {:noreply, state}
  end

  defp update_explosion(updater, dt, state) do
    age = state.explosion + dt / @explosion_time
    state = %State{state | explosion: age}

    if age <= 1.0 do
      update = %Tanx.Core.Updates.Explosion{pos: {state.x, state.y}, radius: @explosion_radius, age: age}
      updater |> Tanx.Core.ArenaUpdater.send_update_reply(update)
      {:noreply, state}
    else
      Tanx.Core.Player.explode_missile(state.player, self)
      updater |> Tanx.Core.ArenaUpdater.send_update_reply(nil)
      {:stop, :normal, state}
    end
  end

  defp _hit_obstacle?(x_pos, y_pos, state) do
    state.decomposed_walls
      |> Enum.find_value(fn(wall) -> Tanx.Core.Obstacles.collision_with_decomposed_wall(wall,
                                                       {state.x, state.y}, 
                                                       {x_pos, y_pos}) end
      )
  end

  defp _hit_arena_edge?(x_pos, y_pos, state) do
    y_pos > state.arena_height or x_pos > state.arena_width 
  end
end
