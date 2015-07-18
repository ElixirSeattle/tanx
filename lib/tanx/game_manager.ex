defmodule Tanx.GameManager do

  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, nil)
  end


  defmodule PlayerEvent do
    use GenEvent

    def handle_event({:player_views, player_views}, state) do
      # Broadcast the player list to clients in the lobby
      Tanx.Endpoint.broadcast!("lobby", "view_players", %{players: player_views})
      # Clients that have a player should get a customized view. Broadcast an empty payload,
      # and the handle_out callbacks will take care of generating the view.
      Tanx.Endpoint.broadcast!("player", "view_players", %{})
      {:ok, state}
    end

  end


  #### GenServer callbacks

  use GenServer


  def init(_opts) do
    Tanx.Core.Game.start_link(name: :game_core, player_change_handler: {PlayerEvent, nil})
  end

end
