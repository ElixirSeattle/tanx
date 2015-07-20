defmodule Tanx.Core.PlayerManager do

  @moduledoc """
  The PlayerManager is an internal process that keeps track of players connected to the game.
  It handles creation of Player endpoint processes, responds to requests to view the
  player list, and deals with players leaving.

  This is not part of the Tanx.Core interface. Hence there are no public API functions in
  this module. You generally interact with the PlayerManager through the Game module.
  """


  #### GenServer callbacks

  use GenServer


  # Represents the metadata of a single player
  defmodule PlayerInfo do
    defstruct name: "", kills: 0, deaths: 0
  end


  # The state for this process. Includes handles to other processes needed by players, and
  # a mapping of player process IDs to PlayerInfo structs.
  defmodule State do
    defstruct arena_objects: nil, arena_view: nil, players: HashDict.new, broadcaster: nil
  end


  def init({arena_objects, arena_view, change_handler, handler_args}) do
    Process.flag(:trap_exit, true)
    if change_handler do
      {:ok, broadcaster} = GenEvent.start_link()
      :ok = broadcaster |> GenEvent.add_handler(change_handler, handler_args)
    else
      broadcaster = nil
    end
    {:ok, %State{arena_objects: arena_objects, arena_view: arena_view, broadcaster: broadcaster}}
  end


  # Called by the 'game' process to create a Player when one connects. Returns:
  # - {:ok, player} if successful
  # - {:error, reason} if not
  def handle_call({:create_player, name}, _from, state) do
    {:ok, player} = GenServer.start_link(Tanx.Core.Player,
      {self, state.arena_objects, state.arena_view})
    player_info = %PlayerInfo{name: name}
    players = state.players |> Dict.put(player, player_info)
    state = %State{state | players: players}
    _broadcast_change(state)
    {:reply, {:ok, player}, state}
  end


  # Returns a list of Tanx.Core.View.Player representing the players.
  # If called from a Player, that player's :is_me field will be set to true.
  def handle_call(:view_all, {from, _}, state) do
    player_views = state.players
      |> Enum.map(fn
        ({player, %PlayerInfo{name: name, kills: kills, deaths: deaths}}) ->
          %Tanx.Core.View.Player{name: name, kills: kills, deaths: deaths, is_me: from == player}
      end)
      |> _sort_views()
    {:reply, player_views, state}
  end


  # Returns the Tanx.Core.View.Player representing the calling Player, or nil if the
  # calling process is not a Player that is part of this game.
  def handle_call({:view_player, player}, {from, _}, state) do
    reply = case state.players[player] do
      nil -> nil
      %PlayerInfo{name: name, kills: kills, deaths: deaths} ->
        %Tanx.Core.View.Player{name: name, kills: kills, deaths: deaths, is_me: from == player}
    end
    {:reply, reply, state}
  end


  # Sets the name of the calling player. Returns :ok or :not_found.
  def handle_call({:rename, name}, {from, _}, state) do
    {reply, state} = case state.players[from] do
      nil -> {:not_found, state}
      player_info ->
        player_info = %PlayerInfo{player_info | name: name}
        {:ok, %State{state | players: state.players |> Dict.put(from, player_info)}}
    end
    _broadcast_change(state)
    {:reply, reply, state}
  end


  # Increments kill count of the given player. Returns :ok or :not_found.
  def handle_call({:inc_kills, player}, _from, state) do
    {reply, state} = case state.players[player] do
      nil -> {:not_found, state}
      player_info ->
        player_info = player_info |> Dict.update!(:kills, &(&1 + 1))
        {:ok, %State{state | players: state.players |> Dict.put(player, player_info)}}
    end
    _broadcast_change(state)
    {:reply, reply, state}
  end


  # Increments death count of the given player. Returns :ok or :not_found.
  def handle_call({:inc_deaths, player}, _from, state) do
    {reply, state} = case state.players[player] do
      nil -> {:not_found, state}
      player_info ->
        player_info = player_info |> Dict.update!(:deaths, &(&1 + 1))
        {:ok, %State{state | players: state.players |> Dict.put(player, player_info)}}
    end
    _broadcast_change(state)
    {:reply, reply, state}
  end


  # Remove the calling player. Returns :ok (regardless of whether the caller was a player
  # that was removed or not).
  def handle_call(:player_left, {from, _}, state) do
    state = _remove_player(from, state)
    {:reply, :ok, state}
  end


  # Trap EXIT to handle the death of Player processes. If a Player dies, remove it.
  def handle_info({:EXIT, pid, _}, state) do
    {:noreply, _remove_player(pid, state)}
  end
  def handle_info(request, state), do: super(request, state)


  #### Internal utils


  # Remove the given player from the current list.
  defp _remove_player(player, state) do
    GenServer.call(state.arena_objects, {:player_left, player})
    state = %State{state | players: state.players |> Dict.delete(player)}
    _broadcast_change(state)
    state
  end

  defp _broadcast_change(state = %State{broadcaster: nil}), do: state
  defp _broadcast_change(state) do
    player_views = state.players
      |> Enum.map(fn
        ({_, %PlayerInfo{name: name, kills: kills, deaths: deaths}}) ->
          %Tanx.Core.View.Player{name: name, kills: kills, deaths: deaths}
      end)
      |> _sort_views()
    GenEvent.notify(state.broadcaster, {:player_views, player_views})
    state
  end

  defp _sort_views(views) do
    views |> Enum.sort_by(fn
      %Tanx.Core.View.Player{name: name, is_me: is_me} -> {!is_me, name}
    end)
  end

end
