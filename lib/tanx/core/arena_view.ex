defmodule Tanx.Core.ArenaView do

  @moduledoc """
  The ArenaView is an internal process that stores the latest state of the arena. It is here
  so view requests can be served quickly.

  This is not part of the Tanx.Core interface. Hence there are no public API functions in
  this module. To get the current arena view, call the appropriate function in Tanx.Core.Game
  or Tanx.Core.Player.
  """

  @entry_point_radius 0.5


  #### API internal to Tanx.Core


  @doc """
  Starts an ArenaView process. This should be called only from a Game process.
  """
  def start_link(structure) do
    {:ok, pid} = GenServer.start_link(__MODULE__, {structure})
    pid
  end


  @doc """
  Gets the arena's Tanx.Core.View.Structure.
  """
  def get_structure(arena_view) do
    GenServer.call(arena_view, :get_structure)
  end


  @doc """
  Gets the current list of arena objects as a Tanx.Core.View.Arena.

  If this function is called by a Player process, that player's tanks will have
  the :is_me field set to true, and that player's missiles will have the
  :is_mine field set to true.
  """
  def get_objects(arena_view) do
    GenServer.call(arena_view, :get_objects)
  end


  @doc """
    Update the object list.
  """
  def set_objects(arena_view, tanks, missiles, explosions) do
    GenServer.call(arena_view, {:update, tanks, missiles, explosions})
  end


  @doc """
    Clear the object list.
  """
  def clear_objects(arena_view) do
    set_objects(arena_view, [], [], [])
  end


  #### GenServer callbacks

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

    entry_points = structure.entry_points
      |> Enum.map(fn ep ->
        %Tanx.Core.View.EntryPoint{x: ep.x, y: ep.y, name: ep.name}
      end)

    structure_view = %Tanx.Core.View.Structure{
      height: structure.height,
      width: structure.width,
      walls: walls,
      entry_point_radius: @entry_point_radius,
      entry_points: entry_points
    }
    {:ok, %State{structure: structure_view}}
  end


  # This may be called to get the current structure view.
  def handle_call(:get_structure, _from, state) do
    {:reply, state.structure, state}
  end


  # This may be called to get the current arena view. If it is called by a Player process,
  # that player's tanks will have the :is_me field set to true.
  def handle_call(:get_objects, {from, _}, state) do
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

    view = %Tanx.Core.View.Arena{
      tanks: tanks,
      missiles: missiles,
      explosions: state.explosions
    }

    {:reply, view, state}
  end


  # This is called from an updater to update the view with a new state.
  def handle_call({:update, tanks, missiles, explosions}, _from, state) do
    tanks = tanks
      |> Enum.map(fn tank ->
        %Tanx.Core.ArenaView.TankInfo{tank |
          x: tank.x |> truncate, y: tank.y |> truncate,
          heading: tank.heading |> truncate}
      end)

    missiles = missiles
      |> Enum.map(fn missile ->
        %Tanx.Core.ArenaView.MissileInfo{missile |
          x: missile.x |> truncate, y: missile.y |> truncate,
          heading: missile.heading |> truncate}
      end)

    explosions = explosions
      |> Enum.map(fn explosion ->
        %Tanx.Core.View.Explosion{explosion |
          x: explosion.x |> truncate, y: explosion.y |> truncate,
          age: explosion.age |> truncate}
      end)

    {:reply, :ok, %State{state | tanks: tanks, missiles: missiles, explosions: explosions}}
  end


  defp truncate(value), do: round(value * 100) / 100


end
