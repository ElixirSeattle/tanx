defmodule Tanx.Core.Player do

  @moduledoc """
  The Player process is the entry point for a connected player.

  To connect to a game, call Tanx.Core.Game.connect, which returns a player reference.
  That reference can then be passed to functions in this module to control the player.
  """


  #### Public API


  @doc """
  Returns a view of the connected players, as a list of Tanx.Core.View.Player structs.
  The current player will have the :is_me field set to true.
  """
  def view_players(player) do
    GenServer.call(player, :view_players)
  end


  @doc """
  Returns a view of the current player only, as a Tanx.Core.View.Player struct.
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
  Returns a view of the current arena state, as a Tanx.Core.View.Arena struct.
  The current player's tank (if any) will have its :is_me field set to true.
  """
  def view_arena(player) do
    GenServer.call(player, :view_arena)
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
    GenServer.call(player, :new_missile)
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
  Removes the tank for the player, and returns either :ok or :no_tank.
  """
  def remove_tank(player) do
    GenServer.call(player, :remove_tank)
  end


  @doc """
  Sends a control message to the tank in the form of a button press or release.

  Supported buttons are:

  - **:forward** Move forward
  - **:left** Rotate left
  - **:right** Rotate right

  TODO: implement fire button and other controls.
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


  #### GenServer callbacks

  use GenServer


  defmodule State do
    defstruct player_manager: nil,
              arena_objects: nil,
              arena_view: nil,
              current_tank: nil,
              fwdown: false,
              ltdown: false,
              rtdown: false,
              missiles: [],
              last_fired: 0
  end


  @forward_velocity 2.0
  @angular_velocity 2.0


  # This is called by the 'player manager' when creating a new player
  def init({player_manager, arena_objects, arena_view}) do
    {:ok, %State{player_manager: player_manager, arena_objects: arena_objects, arena_view: arena_view}}
  end


  #This is called by the new tank API.
  def handle_call({:new_tank, params}, _from, state) do
    case _maybe_call_tank(state, :ping) do
      {:not_found, state} ->
        tank = GenServer.call(state.arena_objects, {:create_tank, params})
        {:reply, :ok, %State{state | current_tank: tank}}
      {:ok, _, state} ->
        {:reply, :already_present, state}
    end
  end


  def handle_call(:remove_tank, _from, state) do
    tank = state.current_tank
    if tank do
      GenServer.cast(tank, :destroy)
      {:reply, :ok, %State{state | current_tank: nil}}
    else
      {:reply, :no_tank, state}
    end
  end

  def handle_call(:new_missile, _from, state) do
    curr_time = _cur_millis
    if (Dict.size(state.missiles) < 5) and ((curr_time - state.last_fired) > 500) do

      case _maybe_call_tank(state, :get_position) do
        {:not_found, state} ->
          {:reply, :no_tank, state}
        {:ok, nil, state} ->
          {:reply, :no_tank, state}
        {:ok, {x, y, heading}, state } ->
          missile = GenServer.call(state.arena_objects,
                                   {:create_missile, {x, y, heading}})
          {:reply,:ok, %State{state |
                                missiles: [missile | state.missiles],
                                last_fired: curr_time}
                              }
      end
    else
      {:reply, :at_limit, state}
    end
  end

  def handle_call({:explode_missile, missile}, _from, state) do
    tank = state.current_tank
    if tank do
      GenServer.cast(missile, :die)
      {:reply, :ok, %State{state | missiles: List.remove(state.missiles, missile)}}
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

  def handle_call(:missile_count, _from, state) do
    {:reply, Dict.size(state.missiles), state}
  end


  def handle_call({:control_tank, button, is_down}, _from, state) do
    state = _movement_state(state, button, is_down)
    v = if state.fwdown, do: @forward_velocity, else: 0.0
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

  def handle_call(:view_players, _from, state) do
    view = GenServer.call(state.player_manager, :view_all)
    {:reply, view, state}
  end

  def handle_call(:view_myself, _from, state) do
    view = GenServer.call(state.player_manager, {:view_player, self})
    {:reply, view, state}
  end

  def handle_call(:view_arena, _from, state) do
    view = GenServer.call(state.arena_view, :get)
    {:reply, view, state}
  end

  def handle_call({:rename, name}, _from, state) do
    reply = GenServer.call(state.player_manager, {:rename, name})
    {:reply, reply, state}
  end

  def handle_call(:leave, _from, state) do
    :ok = GenServer.call(state.player_manager, :player_left)
    {:stop, :normal, :ok, %State{}}
  end

  #### Internal utils
  defp _maybe_call_tank(state = %State{current_tank: nil}, _call) do
    {:not_found, state}
  end

  defp _maybe_call_tank(state = %State{current_tank: tank}, call) do
    try do
      {:ok, GenServer.call(tank, call), state}
    catch :exit, {:noproc, _} ->
      {:not_found, %State{state | current_tank: nil}}
    end
  end


  defp _movement_state(state, "left", true), do: %State{state | ltdown: true, rtdown: false}
  defp _movement_state(state, "left", false), do: %State{state | ltdown: false}
  defp _movement_state(state, "right", true), do: %State{state | rtdown: true, ltdown: false}
  defp _movement_state(state, "right", false), do: %State{state | rtdown: false}
  defp _movement_state(state, "forward", value), do: %State{state | fwdown: value}
  # TODO: Fire button - do we need a fire button state?
  defp _movement_state(state, _button, _down), do: state

  defp _cur_millis() do
    # TODO: Use new time API in Erlang 18
    {gs, s, ms} = :erlang.now()
    gs * 1000000000 + s * 1000 + div(ms, 1000)
  end
end
