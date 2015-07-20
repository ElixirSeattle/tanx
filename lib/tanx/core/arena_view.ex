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
    @moduledoc """
      This struct holds the current state of the arena
      structure - This a Tanx.Core.Structure which describes the shape of the 
                  areana.
      tanks - this is a collection of 
    """
    defstruct structure: nil, tanks: [], missiles: []
  end

  defmodule TankInfo do
    defstruct player: nil, name: "", x: 0.0, y: 0.0, heading: 0.0, radius: 0.5
  end

  defmodule MissileInfo do 
    defstruct player: nil, name: "", x: 0.0, y: 0.0, a: 0.0
  end


  def init({structure}) do
    {:ok, %State{structure: structure || %Tanx.Core.Structure{}}}
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
        %Tanx.Core.View.Missile{is_mine: missile_info.player == from, name: missile_info.name,
          x: missile_info.x, y: missile_info.y, a: missile_info.a}
      end)

    {:reply, %Tanx.Core.View.Arena{structure: state.structure, 
                                   tanks: tanks, 
                                   missiles: missiles}, state}
  end


  # This is called from an updater to update the view with a new state.
  def handle_call({:update, {tanks, missiles}}, _from, state) do
    {:reply, :ok, %State{state | tanks: tanks, missiles: missiles}}
  end


end
