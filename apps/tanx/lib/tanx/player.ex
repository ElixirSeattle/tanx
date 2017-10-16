defmodule Tanx.Player do

  @moduledoc """
  The Player process is the entry point for a connected player.

  To connect to a game, call Tanx.Game.connect, which returns a player reference.
  That reference can then be passed to functions in this module to control the player.
  """


  #### Public API


  @doc """
  Returns a view of the connected players, as a list of Tanx.View.Player structs.
  The current player will have the :is_me field set to true.
  """
  def view_players(player) do
    GenServer.call(player, :view_players)
  end


  @doc """
  Returns a view of the current player only, as a Tanx.View.Player struct.
  """
  def view_myself(player) do
    GenServer.call(player, :view_myself)
  end


  @doc """
  Sets the player name
  """
  def rename(player, name) do
    GenServer.call(player, {:rename, name})
  end


  @doc """
  Returns a view of the current arena state, as a Tanx.View.Arena struct.
  The current player's tank (if any) will have its :is_me field set to true.
  """
  def view_arena_objects(player, params \\ []) do
    GenServer.call(player, {:view_arena_objects, params})
  end


  @doc """
  Returns a view of the arena structure, as a Tanx.View.Structure.
  """
  def view_arena_structure(player) do
    GenServer.call(player, :view_arena_structure)
  end


  @doc """
  Starts a new tank for the player, and returns either :ok or :already_present.
  """
  def new_tank(player, params \\ []) do
    GenServer.call(player, {:new_tank, params})
  end

  @doc """
    Create a new missile for the specified player. Returns :ok or :at_limit if
    the maximum missile count has been reached.
  """
  def new_missile(player) do
    GenServer.call(player, {:control_tank, "fire", true})
  end

  @doc """
    Remove a specific missile from a specific player.
  """
  def explode_missile(player, missile) do
    GenServer.call(player, {:explode_missile, missile})
  end

  @doc """
  Returns true if the player currently has a live tank in the arena.
  """
  def has_tank?(player) do
    GenServer.call(player, :has_tank)
  end

  @doc """
  Returns true if the player currently has a live tank in the arena.
  """
  def missile_count(player) do
    GenServer.call(player, :missile_count)
  end


  @doc """
  Self-destructs the tank for the player, and returns either :ok or :no_tank.
  """
  def self_destruct_tank(player) do
    GenServer.call(player, :self_destruct_tank)
  end


  @doc """
    Increment the kill count of the calling player.
  """
  def inc_kills(player) do
    GenServer.call(player, :inc_kills)
  end


  @doc """
    Increment the death count of the calling player.
  """
  def inc_deaths(player) do
    GenServer.call(player, :inc_deaths)
  end

  @doc """
    Add a power up to the player.
  """
  def addPowerUp(player, type) do
    GenServer.call(player, {:add_powerup, type})
  end


  @doc """
    Gets the power ups on the player.
  """
  def get_powerups(player) do
    GenServer.call(player, :get_powerups)
  end


  @doc """
  Sends a control message to the tank in the form of a button press or release.

  Supported buttons are:

  - **:forward** Move forward
  - **:left** Rotate left
  - **:right** Rotate right
  - **:fire** Fire missile
  """
  def control_tank(player, button, is_down) do
    GenServer.call(player, {:control_tank, button, is_down})
  end


  @doc """
  Leave the game. This immediately removes the player's tank from the arena and loses
  the player's stats.
  """
  def leave(player) do
    GenServer.call(player, :leave)
  end


  #### API internal to Tanx


  @doc """
    Start a new player. This should be called only by PlayerManager.
  """
  def start_link(player_manager, arena_objects, arena_view, time_config) do
    {:ok, player} = GenServer.start_link(__MODULE__,
        {player_manager, arena_objects, arena_view, time_config})
    player
  end


  #### GenServer callbacks

  use GenServer


  defmodule State do
    defstruct player_manager: nil,
              arena_objects: nil,
              arena_view: nil,
              time_config: nil,
              current_tank: nil,
              fwdown: false,
              ltdown: false,
              rtdown: false,
              bwdown: false,
              missiles: [],
              last_fired: -1000,
              powerups: %{wall_bounce: 0}
  end


  @forward_velocity 2.0
  @backward_velocity 1.0
  @angular_velocity 2.0
  @missile_fire_rate 200

  # This is called by the 'player manager' when creating a new player
  def init({player_manager, arena_objects, arena_view, time_config}) do
    state = %State{
      player_manager: player_manager,
      arena_objects: arena_objects,
      arena_view: arena_view,
      time_config: time_config
    }
    {:ok, state}
  end


  #This is called by the new tank API.
  def handle_call({:new_tank, params}, _from, state) do
    case _maybe_call_tank(state, :ping) do
      {:not_found, state} ->
        case state.arena_objects |> Tanx.ArenaObjects.create_tank(params) do
          {:ok, tank} ->
            {:reply, :ok, %State{state | current_tank: tank, missiles: [], powerups: %{wall_bounce: 0}}}
          {:error, error} ->
            {:reply, error, state}
        end
      {:ok, _, state} ->
        {:reply, :already_present, state}
    end
  end


  def handle_call(:self_destruct_tank, _from, state) do
    tank = state.current_tank
    if tank do
      state.player_manager |> Tanx.PlayerManager.inc_deaths(self())
      tank |> Tanx.Tank.self_destruct
      {:reply, :ok, %State{state | current_tank: nil,  missiles: [], powerups: %{wall_bounce: 0}}}
    else
      {:reply, :no_tank, state}
    end
  end


  def handle_call({:explode_missile, missile}, _from, state) do
    tank = state.current_tank
    if tank do
      :ok = state.arena_objects |> Tanx.ArenaObjects.explode_missile(missile)
      {:reply, :ok, %State{state | missiles: List.delete(state.missiles, missile)}}
    else
      {:reply, :no_missile, state}
    end
  end

  def handle_call(:has_tank, _from, state) do
    {:reply, state.current_tank != nil, state}
  end

  def handle_call({:control_tank, button, is_down}, from, state) when is_atom(button) do
    handle_call({:control_tank, Atom.to_string(button), is_down}, from, state)
  end

  def handle_call({:control_tank, "fire", true}, _from, state) do
    curr_time = Tanx.SystemTime.get(state.time_config)
    if (curr_time - state.last_fired) >= @missile_fire_rate do

      case _maybe_call_tank(state, :get_position) do
        {:not_found, state} ->
          {:reply, :no_tank, state}
        {:ok, nil, state} ->
          {:reply, :no_tank, state}
        {:ok, {x, y, heading, tank_radius}, state } ->
          missile = state.arena_objects
           |> Tanx.ArenaObjects.create_missile(x,
                                                    y,
                                                    heading,
                                                    tank_radius,
                                                    state.powerups.wall_bounce)
          {:reply,:ok, %State{state |
                                missiles: [missile | state.missiles],
                                last_fired: curr_time}
                              }
      end
    else
      {:reply, :at_limit, state}
    end
  end

  def handle_call({:control_tank, "fire", false}, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call({:control_tank, button, is_down}, _from, state) do
    state = _movement_state(state, button, is_down)
    v = cond do
      state.fwdown -> @forward_velocity
      state.bwdown -> 0 - @backward_velocity
      true -> 0.0
    end
    av = cond do
      state.ltdown -> @angular_velocity
      state.rtdown -> -@angular_velocity
      true -> 0.0
    end
    case _maybe_call_tank(state, {:control_movement, v, av}) do
      {:not_found, state} -> {:reply, :no_tank, state}
      {:ok, _, state} -> {:reply, :ok, state}
    end
  end

  def handle_call(:missile_count, _from, state) do
    {:reply, length(state.missiles), state}
  end

  def handle_call(:view_players, _from, state) do
    view = state.player_manager |> Tanx.PlayerManager.view_all_players
    {:reply, view, state}
  end

  def handle_call(:view_myself, _from, state) do
    view = state.player_manager |> Tanx.PlayerManager.view_player(self())
    {:reply, view, state}
  end

  def handle_call({:view_arena_objects, params}, _from, state) do
    view = state.arena_view |> Tanx.ArenaView.get_objects(params)
    {:reply, view, state}
  end

  def handle_call(:view_arena_structure, _from, state) do
    view = state.arena_view |> Tanx.ArenaView.get_structure()
    {:reply, view, state}
  end

  def handle_call({:rename, name}, _from, state) do
    reply = state.player_manager |> Tanx.PlayerManager.rename(name)
    {:reply, reply, state}
  end

  def handle_call(:leave, _from, state) do
    :ok = state.player_manager |> Tanx.PlayerManager.remove_player
    {:stop, :normal, :ok, %State{}}
  end

  def handle_call(:inc_kills, _from, state) do
    reply = state.player_manager |> Tanx.PlayerManager.inc_kills(self())
    {:reply, reply, state}
  end

  def handle_call(:inc_deaths, _from, state) do
    state = %State{state | powerups: %{}}
    reply = state.player_manager |> Tanx.PlayerManager.inc_deaths(self())
    {:reply, reply, state}
  end

  def handle_call({:add_powerup, type}, _from, state) do
    state = case type do
      %Tanx.PowerUpTypes.BouncingMissile{} ->
        %State{state | powerups: Map.put(state.powerups, :wall_bounce, type.bounce_count)}
      %Tanx.PowerUpTypes.HealthKit{} ->
        Tanx.Tank.adjust(state.current_tank, nil, nil, 2.0)
        state
      _ -> state
    end
    {:reply, :ok, state}
  end

  def handle_call(:get_powerups, _from, state) do
    {:reply, state.powerups, state}
  end

  #### Internal utils
  defp _maybe_call_tank(state = %State{current_tank: nil}, _call) do
    {:not_found, state}
  end

  defp _maybe_call_tank(state = %State{current_tank: tank}, call) do
    try do
      {:ok, GenServer.call(tank, call), state}
    catch :exit, {:noproc, _} ->
      {:not_found, %State{state | current_tank: nil, missiles: []}}
    end
  end


  defp _movement_state(state, "left", true), do: %State{state | ltdown: true, rtdown: false}
  defp _movement_state(state, "left", false), do: %State{state | ltdown: false}
  defp _movement_state(state, "right", true), do: %State{state | rtdown: true, ltdown: false}
  defp _movement_state(state, "right", false), do: %State{state | rtdown: false}
  defp _movement_state(state, "forward", value), do: %State{state | fwdown: value}
  defp _movement_state(state, "backward", value), do: %State{state | bwdown: value}

  # TODO: Fire button - do we need a fire button state?
  defp _movement_state(state, _button, _down), do: state
end
