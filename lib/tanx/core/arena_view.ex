defmodule Tanx.Core.ArenaView do

  @moduledoc """
  The ArenaView is an internal process that stores the latest state of the arena. It is here
  so view requests can be served quickly.

  This is not part of the Tanx.Core interface. Hence there are no public API functions in
  this module. To get the current arena view, call the appropriate function in Tanx.Core.Game
  or Tanx.Core.Player.
  """


  # GenServer callbacks

  use GenServer

  defmodule State do
    defstruct structure: nil,  # Tanx.Core.View.Structure
              tanks: [],       # list of TankInfo
              missiles: [],    # list of MissileInfo
              explosions: []   # list of Tanx.Core.View.Explosion
  end

  defmodule TankInfo do
    defstruct player: nil,
              name: "",
              x: 0.0,
              y: 0.0,
              heading: 0.0,
              radius: 0.5
  end

  defmodule MissileInfo do
    defstruct player: nil,
              x: 0.0,
              y: 0.0,
              heading: 0.0,
              radius: 0.1
  end


  def init({structure}) do
    walls = structure.walls
      |> Enum.map(fn wall ->
        wall |> Enum.flat_map(&Tuple.to_list/1)
      end)
    structure_view = %Tanx.Core.View.Structure{
      height: structure.height,
      width: structure.width,
      walls: walls
    }
    {:ok, %State{structure: structure_view}}
  end


  # This may be called to get the current arena view. If it is called by a Player process,
  # that player's tanks will have the :is_me field set to true.
  def handle_call(:get, {from, _}, state) do
    tanks = state.tanks
      |> Enum.map(fn tank_info ->
        %Tanx.Core.View.Tank{is_me: tank_info.player == from, name: tank_info.name,
          x: tank_info.x, y: tank_info.y, heading: tank_info.heading, radius: tank_info.radius}
      end)

    missiles = state.missiles
      |> Enum.map(fn missile_info ->
        %Tanx.Core.View.Missile{is_mine: missile_info.player == from,
          x: missile_info.x, y: missile_info.y, heading: missile_info.heading}
      end)

    {:reply, %Tanx.Core.View.Arena{structure: state.structure,
                                   tanks: tanks,
                                   missiles: missiles,
                                   explosions: state.explosions}, state}
  end


  # This is called from an updater to update the view with a new state.
  def handle_call({:update, tanks, missiles, explosions}, _from, state) do
    {:reply, :ok, %State{state | tanks: tanks, missiles: missiles, explosions: explosions}}
  end


end
