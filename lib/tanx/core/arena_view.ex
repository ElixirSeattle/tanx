defmodule Tanx.Core.ArenaView do

  @moduledoc """
  The ArenaView is an internal process that stores the latest state of the arena. It is here
  so view requests can be served quickly.

  This is not part of the Tanx.Core interface. Hence there are no public API functions in
  this module. To get the current arena view, call the appropriate function in Tanx.Core.Game
  or Tanx.Core.Player.
  """

  @entry_point_radius 0.5
  @entry_power_up_radius 0.3

  require Logger


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
  def get_objects(arena_view, params \\ []) do
    GenServer.call(arena_view, :get_objects)
  end


  @doc """
    Update the object list.
  """
  def set_objects(arena_view, tanks, missiles, explosions, powerups, entry_points) do
    GenServer.call(arena_view, {:set_objects, tanks, missiles, explosions, powerups, entry_points})
  end


  @doc """
    Clear the object list.
  """
  def clear_objects(arena_view) do
    set_objects(arena_view, [], [], [], [], nil)
  end


  #### GenServer callbacks

  use GenServer

  defmodule State do
    defstruct structure: nil,        # Tanx.Core.View.Structure
              all_entry_points: %{},  # Default entry_points_available
              tanks: [],             # list of TankInfo
              missiles: [],          # list of MissileInfo
              explosions: [],        # list of Tanx.Core.View.Explosion
              powerups: [],           # list of Tanx.Core.View.PowerUp
              entry_points_available: %{}  # map of entry point name to availability
  end

  defmodule TankInfo do
    defstruct player: nil,
              name: "",
              x: 0.0,
              y: 0.0,
              heading: 0.0,
              radius: 0.5,
              armor: 0.0,
              max_armor: 1.0
  end

  defmodule MissileInfo do
    defstruct player: nil,
              x: 0.0,
              y: 0.0,
              hx: 0.0,
              hy: 0.0,
              radius: 0.1
  end

  defmodule PowerupInfo do
    defstruct x: 0.0,
              y: 0.0,
              radius: 0.4,
              type: nil
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

    all_entry_points = structure.entry_points
      |> Enum.reduce(%{}, fn (ep, dict) ->
        dict |> Dict.put(ep.name, true)
      end)

    state = %State{
      structure: structure_view,
      all_entry_points: all_entry_points
    }

    {:ok, state}
  end


  # This may be called to get the current structure view.
  def handle_call(:get_structure, _from, state) do
    {:reply, state.structure, state}
  end


  # This may be called to get the current arena view. If it is called by a Player process,
  # that player's tanks will have the :is_me field set to true.
  def handle_call(:get_objects, {from, _}, state) do
    tanks = state.tanks |> Enum.map(tank_view_builder(from))

    missiles = state.missiles |> Enum.map(missile_view_builder(from))
    explosions = state.explosions

    if tanks |> Enum.any?(&(&1.is_me)) do
      entry_points_available = %{}
    else
      entry_points_available = state.entry_points_available
    end

    powerups = state.powerups |> Enum.map(power_up_view_builder())

    view = %Tanx.Core.View.Arena{
      tanks: tanks,
      missiles: missiles,
      explosions: explosions,
      powerups: powerups,
      entry_points_available: entry_points_available
    }

    {:reply, view, state}
  end


  # This is called from an updater to update the view with a new state.
  def handle_call({:set_objects, tanks, missiles, explosions, powerups, entry_points_available}, _from, state) do

    tanks = tanks
      |> Enum.map(fn tank ->
        %TankInfo{tank |
          x: tank.x |> truncate, y: tank.y |> truncate,
          heading: tank.heading |> truncate}
      end)

    missiles = missiles
      |> Enum.map(fn missile ->
        %MissileInfo{missile |
          x: missile.x |> truncate, y: missile.y |> truncate,
          hx: missile.hx |> truncate,
          hy: missile.hy |> truncate
        }
      end)

    explosions = explosions
      |> Enum.map(fn explosion ->
        %Tanx.Core.View.Explosion{explosion |
          x: explosion.x |> truncate, y: explosion.y |> truncate,
          age: explosion.age |> truncate}
      end)

    powerups = powerups |>  Enum.map(fn powerup ->
      %Tanx.Core.View.PowerUp{powerup |
        x: powerup.x |> truncate,
        y: powerup.y |> truncate,
        radius: powerup.radius |> truncate,
        type: powerup.type} #TODO: map the power up map to a string name
      end)

    if entry_points_available == nil do
      entry_points_available = state.all_entry_points
    end

    state = %State{state |
      tanks: tanks,
      missiles: missiles,
      explosions: explosions,
      powerups: powerups,
      entry_points_available: entry_points_available
    }
    {:reply, :ok, state}
  end


  defp truncate(value) do
    round(value * 100) / 100
  end

  defp tank_view_builder(player) do
    fn tank_info ->
      %Tanx.Core.View.Tank{
        is_me: tank_info.player == player,
        name: tank_info.name,
        x: tank_info.x,
        y: tank_info.y,
        heading: tank_info.heading,
        radius: tank_info.radius,
        armor: tank_info.armor,
        max_armor: tank_info.max_armor
      }
    end
  end


  defp missile_view_builder(player) do
    fn missile_info ->
      %Tanx.Core.View.Missile{
        is_mine: missile_info.player == player,
        x: missile_info.x,
        y: missile_info.y,
        hx: missile_info.hx,
        hy: missile_info.hy
      }
    end
  end

  defp power_up_view_builder() do
    fn power_up_info ->
      %Tanx.Core.View.PowerUp{
        x: power_up_info.x,
        y: power_up_info.y,
        radius: power_up_info.radius,
        type: power_up_info.type
      }
    end
  end

end
