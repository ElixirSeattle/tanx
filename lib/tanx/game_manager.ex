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
      structure: structure)
  end

  defp structure do
    pick_structure(%Tanx.Core.Structure.MapDetails{}.maps)
  end

  defp pick_structure(structures, position \\ nil) do
    Enum.at(structures, position || random_element(length(structures)))
  end

  defp random_element(length) do
    << a :: 32, b :: 32, c :: 32 >> = :crypto.rand_bytes(12)
    :random.seed(a, b, c)
    :random.uniform(length) - 1
  end
end

