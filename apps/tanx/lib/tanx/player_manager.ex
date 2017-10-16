defmodule Tanx.PlayerManager do

  @moduledoc """
  The PlayerManager is an internal process that keeps track of players connected to the game.
  It handles creation of Player endpoint processes, responds to requests to view the
  player list, and deals with players leaving.

  This is not part of the Tanx interface. Hence there are no public API functions in
  this module. You generally interact with the PlayerManager through the Game module.
  """


  #### API internal to Tanx


  @doc """
    Starts a PlayerManager process. This should be called only from a Game process.
  """
  def start_link(arena_objects, arena_view, time_config) do
    {:ok, pid} = GenServer.start_link(__MODULE__,
        {arena_objects, arena_view, time_config})
    pid
  end


  @doc """
    Creates a player. Returns {:ok, player} if succeessful, or {:error, reason} if not.
  """
  def create_player(player_manager, player_name) do
    GenServer.call(player_manager, {:create_player, player_name})
  end


  @doc """
    Returns views of all connected players as a list of Tanx.View.Player structs.
    If the calling process is a player, the :is_me field of that player will be set to true.
  """
  def view_all_players(player_manager) do
    GenServer.call(player_manager, :view_all)
  end


  @doc """
    Returns a view of the specified player as a Tanx.View.Player struct.
    If the calling process is a player, the :is_me field of that player will be set to true.
    Returns nil if the specified player was not found.
  """
  def view_player(player_manager, player) do
    GenServer.call(player_manager, {:view_player, player})
  end

  @doc """
    Increment the kill count of the calling player.
  """
  def inc_kills(player_manager, player) do
    GenServer.call(player_manager, {:inc_kills, player})
  end

  @doc """
    Increment the death count of the calling player.
  """
  def inc_deaths(player_manager, player) do
    GenServer.call(player_manager, {:inc_deaths, player})
  end

  @doc """
    Sets the name of the calling player. Returns either :ok or :not_found.
  """
  def rename(player_manager, name) do
    GenServer.call(player_manager, {:rename, name})
  end


  @doc """
    Remove the calling player.
  """
  def remove_player(player_manager) do
    GenServer.call(player_manager, :player_left)
  end


  #### GenServer callbacks

  use GenServer


  # Represents the metadata of a single player
  defmodule PlayerInfo do
    defstruct name: "",
              kills: 0,
              deaths: 0
  end


  # The state for this process. Includes handles to other processes needed by players, and
  # a mapping of player process IDs to PlayerInfo structs.
  defmodule State do
    defstruct arena_objects: nil,
              arena_view: nil,
              time_config: nil,
              players: %{},
              listeners: []
  end


  def init({arena_objects, arena_view, time_config}) do
    Process.flag(:trap_exit, true)

    state = %State{
      arena_objects: arena_objects,
      arena_view: arena_view,
      time_config: time_config
    }
    {:ok, state}
  end


  # Called by the 'game' process to create a Player when one connects. Returns:
  # - {:ok, player} if successful
  # - {:error, reason} if not
  def handle_call({:create_player, name}, _from, state) do
    player = Tanx.Player.start_link(
        self(), state.arena_objects, state.arena_view, state.time_config)
    player_info = %PlayerInfo{name: name}
    players = state.players |> Map.put(player, player_info)
    state = %State{state | players: players}
    _broadcast_change(state)
    {:reply, {:ok, player}, state}
  end


  # Returns a list of Tanx.View.Player representing the players.
  # If called from a Player, that player's :is_me field will be set to true.
  def handle_call(:view_all, {from, _}, state) do
    player_views = state.players
      |> Enum.map(fn
        {player, player_info} ->
          build_player_view(player_info, from == player)
        end)
      |> sort_views()
    {:reply, player_views, state}
  end


  # Returns the Tanx.View.Player representing the given Player, or nil if the
  # given player is not part of this game.
  def handle_call({:view_player, player}, {from, _}, state) do
    reply = case state.players[player] do
      nil -> nil
      player_info -> build_player_view(player_info, from == player)
    end
    {:reply, reply, state}
  end


  # Sets the name of the calling player. Returns :ok or :not_found.
  def handle_call({:rename, name}, {from, _}, state) do
    {reply, state} = case state.players[from] do
      nil -> {:not_found, state}
      player_info ->
        player_info = %PlayerInfo{player_info | name: name}
        {:ok, %State{state | players: state.players |> Map.put(from, player_info)}}
    end
    _broadcast_change(state)
    {:reply, reply, state}
  end


  # Increments kill count of the given player. Returns :ok or :not_found.
  def handle_call({:inc_kills, player}, _from, state) do
    {reply, state} = case state.players[player] do
      nil -> {:not_found, state}
      player_info ->
        player_info = %PlayerInfo{player_info | kills: player_info.kills + 1}
        {:ok, %State{state | players: state.players |> Map.put(player, player_info)}}
    end
    _broadcast_change(state)
    {:reply, reply, state}
  end


  # Increments death count of the given player. Returns :ok or :not_found.
  def handle_call({:inc_deaths, player}, _from, state) do
    {reply, state} = case state.players[player] do
      nil -> {:not_found, state}
      player_info ->
        player_info = %PlayerInfo{player_info | deaths: player_info.deaths + 1}
        {:ok, %State{state | players: state.players |> Map.put(player, player_info)}}
    end
    _broadcast_change(state)
    {:reply, reply, state}
  end


  # Remove the calling player. Returns :ok (regardless of whether the caller was a player
  # that was removed or not).
  def handle_call(:player_left, {from, _}, state) do
    state = internal_remove_player(from, state)
    {:reply, :ok, state}
  end


  def handle_call({:add_listener, listener}, _from, state) do
    state = %State{state | listeners: [listener | state.listeners]}
    {:reply, :ok, state}
  end


  # Trap EXIT to handle the death of Player processes. If a Player dies, remove it.
  def handle_info({:EXIT, pid, _}, state) do
    {:noreply, internal_remove_player(pid, state)}
  end
  def handle_info(request, state), do: super(request, state)




  #### Internal utils


  # Remove the given player from the current list.
  defp internal_remove_player(player, state) do
    :ok = state.arena_objects |> Tanx.ArenaObjects.kill_player_objects(player)
    state = %State{state | players: state.players |> Map.delete(player)}
    _broadcast_change(state)
    state
  end


  defp _broadcast_change(state = %State{listeners: listeners}) do
    player_views = state.players
      |> Enum.map(fn
        {_, player_info} ->
          build_player_view(player_info, false)
        end)
      |> sort_views()
    Enum.each(listeners, fn listener ->
      listener.({:player_views, player_views})
    end)
    state
  end


  defp build_player_view(%PlayerInfo{name: name, kills: kills, deaths: deaths}, is_me) do
    name =
      if name == nil or name == "" do
        "Anonymous Coward"
      else
        name
      end
    %Tanx.View.Player{name: name, kills: kills, deaths: deaths, is_me: is_me}
  end


  defp sort_views(views) do
    views |> Enum.sort_by(fn
      %Tanx.View.Player{name: name, kills: kills, deaths: deaths} ->
        {deaths - 2 * kills, name}
    end)
  end

end
