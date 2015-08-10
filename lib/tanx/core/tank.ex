defmodule Tanx.Core.Tank do

  @moduledoc """
  This process models a tank.
  """

  require Logger


  @tank_radius 0.5
  @tank_collision_buffer 0.1
  @chain_reaction_buffer 0.2
  @normal_explosion_radius 1.0
  @normal_explosion_time 0.6
  @self_destruct_explosion_radius 2.0
  @self_destruct_explosion_time 1.0


  #### API internal to Tanx.Core


  @doc """
    Starts a tank process. Called from ArenaObjects.
  """
  def start_link(arena_width, arena_height, decomposed_walls, player, params) do
    {:ok, pid} = GenServer.start_link(__MODULE__,
        {arena_width, arena_height, decomposed_walls, player, params})
    pid
  end


  @doc """
    Returns the tank radius used for collision detection
  """
  def collision_radius(), do: @tank_radius + @tank_collision_buffer


  @doc """
    Returns the tank radius used for chain reaction detection
  """
  def chain_radius(), do: @tank_radius - @chain_reaction_buffer


  @doc """
    Destroys the tank
  """
  def destroy(tank, destroyer) do
    GenServer.cast(tank, {:destroy, destroyer})
  end


  @doc """
    Self-destructs the tank
  """
  def self_destruct(tank) do
    GenServer.cast(tank, :self_destruct)
  end


  @doc """
    Adjusts the tank's position
  """
  def move_to(tank, x, y) do
    GenServer.cast(tank, {:move_to, x, y})
  end


  # GenServer callbacks


  use GenServer

  defmodule State do
    defstruct arena_width: 20.0,
              arena_height: 20.0,
              decomposed_walls: [],
              player: nil,
              pos: {0.0, 0.0},
              heading: 0.0,
              velocity: 0.0,
              angular_velocity: 0.0,
              explosion_progress: nil,
              explosion_originator: nil,
              explosion_time: nil,
              explosion_radius: nil
  end


  def init({arena_width, arena_height, decomposed_walls, player, params}) do
    x = Keyword.get(params, :x, 0)
    y = Keyword.get(params, :y, 0)
    heading = Keyword.get(params, :heading, 0)
    state = %State{arena_width: arena_width, arena_height: arena_height,
      decomposed_walls: decomposed_walls,
      player: player, pos: {x, y}, heading: heading}
    {:ok, state}
  end


  def handle_call(:get_position, _from, state = %State{explosion_progress: nil}) do
    {x, y} = state.pos
    {:reply, {x, y, state.heading}, state}
  end
  def handle_call(:get_position, _from, state) do
    {:reply, nil, state}
  end


  def handle_call({:control_movement, velocity, angular_velocity}, _from, state) do
    {:reply, :ok, %State{state | velocity: velocity || state.velocity,
      angular_velocity: angular_velocity || state.angular_velocity}}
  end


  def handle_call(:ping, _from, state) do
    {:reply, :ok, state}
  end


  def handle_cast({:destroy, destroyer}, state) do
    state = do_destroy(state, destroyer)
    {:noreply, state}
  end


  def handle_cast(:self_destruct, state) do
    state = do_destroy(state, nil)
    {:noreply, state}
  end


  def handle_cast({:update, last_time, time, updater}, state) do
    dt = max((time - last_time) / 1000, 0.0)
    if state.explosion_progress == nil do
      update_tank(updater, dt, state)
    else
      update_explosion(updater, dt, state)
    end
  end


  def handle_cast({:move_to, x, y}, state = %State{explosion_progress: nil}) do
    state = %State{state | pos: {x, y}}
    {:noreply, state}
  end

  def handle_cast({:move_to, _x, _y}, state) do
    {:noreply, state}
  end


  def handle_cast(:die, state) do
    {:stop, :normal, state}
  end


  defp do_destroy(state, destroyer) do
    if state.explosion_progress == nil do
      if destroyer == nil do
        explosion_time = @self_destruct_explosion_time
        explosion_radius = @self_destruct_explosion_radius
        originator = state.player
      else
        explosion_time = @normal_explosion_time
        explosion_radius = @normal_explosion_radius
        originator = destroyer
      end
      %State{state |
        explosion_progress: 0.0,
        explosion_originator: originator,
        explosion_time: explosion_time,
        explosion_radius: explosion_radius
      }
    else
      state
    end
  end


  defp update_explosion(updater, dt, state) do
    old_age = state.explosion_progress
    age = old_age + dt / state.explosion_time
    state = %State{state | explosion_progress: age}

    if age <= 1.0 do
      chain_radius = if old_age < 0.5 and age >= 0.5 do
        state.explosion_radius
      else
        nil
      end
      update = %Tanx.Core.Updates.Explosion{
        pos: state.pos,
        radius: state.explosion_radius,
        chain_radius: chain_radius,
        age: age,
        originator: state.explosion_originator
      }
      updater |> Tanx.Core.ArenaUpdater.send_update_reply(update)
      {:noreply, state}
    else
      updater |> Tanx.Core.ArenaUpdater.send_update_reply(nil)
      {:stop, :normal, state}
    end
  end


  defp update_tank(updater, dt, state) do
    new_heading = new_heading(state, dt)
    pos = new_pos(state, new_heading, dt)

    force = Tanx.Core.Obstacles.force_from_decomposed_walls(
      state.decomposed_walls, pos, @tank_radius + @tank_collision_buffer)

    update = %Tanx.Core.Updates.MoveTank{tank: self, player: state.player,
      pos: pos, heading: new_heading, radius: @tank_radius, force: force}
    updater |> Tanx.Core.ArenaUpdater.send_update_reply(update)

    state = %State{state | pos: pos, heading: new_heading}
    {:noreply, state}
  end


  defp new_heading(state, dt) do
    new_heading = state.heading + state.angular_velocity * dt
    pi = :math.pi()
    cond do
      new_heading > pi -> new_heading - (2 * pi)
      new_heading < -pi -> new_heading + (2 * pi)
      true -> new_heading
    end
  end

  defp new_pos(state, new_heading, dt) do
    dist = state.velocity * dt
    {x, y} = state.pos
    new_x = x + dist * :math.cos(new_heading)
    new_y = y + dist * :math.sin(new_heading)
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

end
