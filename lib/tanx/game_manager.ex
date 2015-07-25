defmodule Tanx.GameManager do

  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, nil)
  end


  defmodule PlayerEvent do
    use GenEvent

    def handle_event({:player_views, player_views}, state) do
      Tanx.Endpoint.broadcast!("game", "view_players", %{players: player_views})
      {:ok, state}
    end

  end


  #### GenServer callbacks

  use GenServer


  def init(_opts) do
    Tanx.Core.Game.start_link(name: :game_core,
      player_change_handler: {PlayerEvent, nil},
      structure: %Tanx.Core.Structure{
        width: 24.0, height: 24.0,
        walls: [
          [{-3, 8}, {3, 8}, {0, 4}],
          [{8, 3}, {8, -3}, {4, 0}],
          [{3, -8}, {-3, -8}, {0, -4}],
          [{-8, -3}, {-8, 3}, {-4, 0}],
          [{-12, -12}, {12, -12}, {12, 12}, {-12, 12}]
        ]
      })
  end

end
