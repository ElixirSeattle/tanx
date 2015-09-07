defmodule Tanx.Core.Missile do

  require Logger


  defmodule State do
    defstruct arena_width: 20.0,
              arena_height: 20.0,
              decomposed_walls: [],
              player: nil,
              x: 0.0,
              y: 0.0,
              heading: 0.0,
              v: 10.0,
              explosion: nil,
              wall_bounce: 0
  end

  @explosion_radius 0.5
  @explosion_time 0.4
  @explosion_intensity 0.25

  ############
  #Missile API

  #Called by "Arena Objects" process.
  def start_link(player, arena_width, arena_height, decomposed_walls, x, y, a, bounces \\ 0) do
    GenServer.start_link(__MODULE__, {player, arena_width, arena_height, decomposed_walls, x, y, a, bounces})
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

  def init({player, arena_width, arena_height, decomposed_walls, x, y, a, wall_bounce}) do
    {:ok, %Tanx.Core.Missile.State{arena_width: arena_width,
                                  arena_height: arena_height,
                                  decomposed_walls: decomposed_walls,
                                  player: player,
                                  x: x,
                                  y: y,
                                  heading: a,
                                  wall_bounce: wall_bounce}}
  end

  def handle_cast({:update, last_time, time, updater}, state) do
    dt = max((time - last_time) / 1000, 0.0)
    if state.explosion == nil do
      update_missile(updater, dt, state)
    else
      update_explosion(updater, dt, state)
    end
  end


  def handle_cast(:explode, state) do
    if state.explosion == nil do
      state = %State{state | explosion: 0.0}
    end
    {:noreply, state}
  end

  ##############################
  # Helper Functions

  defp update_missile(updater, dt, state) do
    a = state.heading
    v = state.v
    nx = state.x + v * dt * :math.cos(a)
    ny = state.y + v * dt * :math.sin(a)
    wb = state.wall_bounce
    impact = _hit_obstacle?(nx, ny, state)
    if impact == nil and _hit_arena_edge?(nx, ny, state) do
      impact = {nx, ny}
    end

    if impact != nil do
      {nx, ny} = impact
      if wb <= 0 do
        state = %State{state | explosion: 0.0}
        update = %Tanx.Core.Updates.Explosion{pos: impact, radius: @explosion_radius, age: 0.0}
      else
        wb = wb - 1
        update = %Tanx.Core.Updates.MoveMissile{
        missile: self,
        player: state.player,
        pos: {nx, ny},
        heading: _calc_new_heading(a)}
      end
    else
      update = %Tanx.Core.Updates.MoveMissile{
        missile: self,
        player: state.player,
        pos: {nx, ny},
        heading: a}
    end

    state = %State{state | x: nx, y: ny, wall_bounce: wb}
    updater |> Tanx.Core.ArenaUpdater.send_update_reply(update)
    {:noreply, state}
  end


  defp update_explosion(updater, dt, state) do
    old_age = state.explosion
    age = old_age + dt / @explosion_time
    state = %State{state | explosion: age}

    if age <= 1.0 do
      chain_radius = if old_age < 0.5 and age >= 0.5 do
        @explosion_radius
      else
        nil
      end
      update = %Tanx.Core.Updates.Explosion{
        pos: {state.x, state.y},
        radius: @explosion_radius,
        intensity: @explosion_intensity,
        age: age,
        chain_radius: chain_radius,
        originator: state.player
      }
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
      |> Enum.find_value(fn(wall) ->
                           Tanx.Core.Obstacles.collision_with_decomposed_wall(wall,
                                                       {state.x, state.y},
                                                       {x_pos, y_pos}) end)
  end

  defp _hit_arena_edge?(x_pos, y_pos, state) do
    y_pos < (0 - state.arena_height/2) or
    y_pos > (state.arena_height/2) or
    x_pos < (0 - (state.arena_width/2)) or
    x_pos > (state.arena_width/2)
  end

  defp _calc_new_heading(a) do
    #TODO
    a
  end
end
