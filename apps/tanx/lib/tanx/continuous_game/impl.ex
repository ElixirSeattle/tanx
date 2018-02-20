defmodule Tanx.ContinuousGame.Impl do
  defstruct(
    maze: nil,
    player_handles: %{},
    players: %{},
    player_id_map: %{}
  )
end


defimpl Tanx.Game.Variant, for: Tanx.ContinuousGame.Impl do

  alias Tanx.ContinuousGame.Impl
  alias Tanx.ContinuousGame.Player
  alias Tanx.ContinuousGame.PlayerPrivate
  alias Tanx.ContinuousGame.PlayersChanged

  def init_arena(data, _time) do
    arena = Tanx.ContinuousGame.Mazes.get(data.maze)
    %Tanx.Arena{arena | tanks: %{}, missiles: %{}, explosions: %{}, powerups: %{}}
  end

  def view(data, _time, _arena, {:players, player_handle}) do
    %Tanx.ContinuousGame.PlayerListView{
      players: data.players,
      cur_player: Map.get(data.player_handles, player_handle)
    }
  end

  def view(_data, _time, arena, :static) do
    %Tanx.ContinuousGame.StaticView{
      size: arena.size,
      walls: arena.walls,
      entry_points: arena.entry_points
    }
  end

  def view(data, _time, arena, {:arena, player_handle}) do
    %Tanx.ContinuousGame.ArenaView{
      entry_points: arena.entry_points,
      tanks: arena.tanks,
      missiles: arena.missiles,
      explosions: arena.explosions,
      powerups: arena.powerups,
      players: data.players,
      cur_player: Map.get(data.player_handles, player_handle)
    }
  end

  def control(data, time, _arena, {:add_player, name}) do
    player_handles = data.player_handles
    players = data.players
    player_handle = Tanx.Util.ID.create(player_handles)
    player_id = Tanx.Util.ID.create(players)
    player = %Player{name: name, joined_at: time}
    player_private = %PlayerPrivate{player_id: player_id}
    new_players = Map.put(players, player_id, player)
    new_player_handles = Map.put(player_handles, player_handle, player_private)
    new_player_id_map = Map.put(data.player_id_map, player_id, player_handle)
    data = %Impl{data |
      player_handles: new_player_handles,
      players: new_players,
      player_id_map: new_player_id_map
    }
    notification = %PlayersChanged{players: new_players}
    {{:ok, player_handle}, data, [], [notification]}
  end

  def control(data, _time, _arena, {:remove_player, player_handle}) do
    player_handles = data.player_handles
    if Map.has_key?(player_handles, player_handle) do
      player_private = Map.fetch!(player_handles, player_handle)
      tank_id = player_private.tank_id
      player_id = player_private.player_id
      new_player_handles = Map.delete(player_handles, player_handle)
      players = data.players
      {new_players, commands, notifications} =
        case tank_id do
          nil ->
            new_players = Map.delete(players, player_id)
            notification = %PlayersChanged{players: new_players}
            {new_players, [], [notification]}
          false ->
            cmd = %Tanx.Updater.DeleteTank{query: %{player_id: player_id},
              event_data: %{deleting_player_id: player_id}}
            {players, [cmd], []}
          id ->
            cmd = %Tanx.Updater.DeleteTank{id: id, event_data: %{deleting_player_id: player_id}}
            {players, [cmd], []}
        end
      new_player_id_map = Map.delete(data.player_id_map, player_id)
      new_data = %Impl{data |
        players: new_players,
        player_handles: new_player_handles,
        player_id_map: new_player_id_map
      }
      {{:ok, player_handle}, new_data, commands, notifications}
    else
      {{:error, :player_not_found, [player_handle: player_handle]}, data, [], []}
    end
  end

  def control(data, _time, _arena, {:rename_player, player_handle, name}) do
    player_handles = data.player_handles
    players = data.players
    if Map.has_key?(player_handles, player_handle) do
      player_private = Map.fetch!(player_handles, player_handle)
      player_id = player_private.player_id
      player = Map.fetch!(players, player_id)
      new_player = %Player{player | name: name}
      new_players = Map.put(players, player_id, new_player)
      new_data = %Impl{data | players: new_players}
      event = %PlayersChanged{players: new_players}
      {{:ok, player_handle}, new_data, [], [event]}
    else
      {{:error, :player_not_found, [player_handle: player_handle]}, data, [], []}
    end
  end

  def control(data, _time, _arena, {:start_tank, player_handle, entry_point_name}) do
    player_handles = data.player_handles
    if Map.has_key?(player_handles, player_handle) do
      player_private = Map.fetch!(player_handles, player_handle)
      tank_id = player_private.tank_id
      player_id = player_private.player_id
      case tank_id do
        nil ->
          new_player_private = %PlayerPrivate{player_private | tank_id: true}
          new_player_handles = Map.put(player_handles, player_handle, new_player_private)
          command = %Tanx.Updater.CreateTank{
            entry_point_name: entry_point_name,
            armor: 2.0,
            max_armor: 2.0,
            data: %{player_id: player_id},
            event_data: %{player_handle: player_handle}
          }
          {:ok, %Impl{data | player_handles: new_player_handles}, [command], []}
        true ->
          {{:error, :tank_being_created, [player_handle: player_handle]}, data, [], []}
        id ->
          {{:error, :tank_already_present, [player_handle: player_handle, tank_id: id]},
            data, [], []}
      end
    else
      {{:error, :player_not_found, [player_handle: player_handle]}, data, [], []}
    end
  end

  def control(data, _time, _arena, {:control_tank, player_handle, button, is_down}) do
    player_handles = data.player_handles
    if Map.has_key?(player_handles, player_handle) do
      player_private = Map.fetch!(player_handles, player_handle)
      tank_id = player_private.tank_id
      if tank_id == nil || tank_id == true do
        {{:error, :tank_not_found, [player_handle: player_handle]}, data, [], []}
      else
        new_player_private = Map.put(player_private, button, is_down)
        velocity = calc_velocity(new_player_private.forward, new_player_private.backward,
          new_player_private.forward_speed, new_player_private.backward_speed)
        angular_velocity = calc_angular_velocity(
          new_player_private.left, new_player_private.right, new_player_private.angular_speed)
        command = %Tanx.Updater.SetTankVelocity{
          id: tank_id, velocity: velocity, angular_velocity: angular_velocity
        }
        new_player_handles = Map.put(player_handles, player_handle, new_player_private)
        {:ok, %Impl{data | player_handles: new_player_handles}, [command], []}
      end
    else
      {{:error, :player_not_found, [player_handle: player_handle]}, data, [], []}
    end
  end

  def control(data, _time, _arena, {:destruct_tank, player_handle}) do
    player_handles = data.player_handles
    if Map.has_key?(player_handles, player_handle) do
      player_private = Map.fetch!(player_handles, player_handle)
      tank_id = player_private.tank_id
      if tank_id == nil || tank_id == true do
        {{:error, :tank_not_found, [player_handle: player_handle]}, data, [], []}
      else
        command = %Tanx.Updater.ExplodeTank{
          id: tank_id,
          explosion_intensity: 4.0,
          explosion_radius: 2.5,
          explosion_length: 1.0,
          chain_data: %{originator_id: player_private.player_id}
        }
        {:ok, data, [command], []}
      end
    else
      {{:error, :player_not_found, [player_handle: player_handle]}, data, [], []}
    end
  end

  def event(
    data, _time, _arena,
    %Tanx.Updater.TankCreated{id: tank_id, event_data: %{player_handle: player_handle}}
  ) do
    player_handles = data.player_handles
    player_private = Map.fetch!(player_handles, player_handle)
    new_player_private = %PlayerPrivate{player_private | tank_id: tank_id}
    new_player_handles = Map.put(player_handles, player_handle, new_player_private)
    {%Impl{data | player_handles: new_player_handles}, []}
  end

  def event(
    data, _time, _arena,
    %Tanx.Updater.TankDeleted{event_data: %{deleting_player_id: player_id}}
  ) do
    new_players = Map.delete(data.players, player_id)
    notification = %PlayersChanged{players: new_players}
    {%Impl{data | players: new_players}, [notification]}
  end

  def event(
    data, _time, _arena,
    %Tanx.Updater.TankDeleted{tank: tank, event_data: %{originator_id: originator_id}}
  ) do
    owner_id = tank.data[:player_id]
    players = data.players
    player_id_map = data.player_id_map
    player_handles = data.player_handles
    if Map.has_key?(player_id_map, owner_id) do
      owner_handle = Map.fetch!(player_id_map, owner_id)
      owner_private = Map.fetch!(player_handles, owner_handle)
      new_owner_private = %PlayerPrivate{owner_private | tank_id: nil}
      new_player_handles = Map.put(player_handles, owner_handle, new_owner_private)
      owner = Map.fetch!(players, owner_id)
      new_owner = %Player{owner | deaths: owner.deaths + 1}
      new_players = Map.put(players, owner_id, new_owner)
      new_players =
        if originator_id == owner_id do
          new_players
        else
          originator = Map.fetch!(players, originator_id)
          new_originator = %Player{originator | kills: originator.kills + 1}
          Map.put(players, originator_id, new_originator)
        end
      notification = %PlayersChanged{players: new_players}
      {%Impl{data | player_handles: new_player_handles, players: new_players}, [notification]}
    else
      {data, []}
    end
  end

  def event(data, _time, _arena, _event) do
    {data, []}
  end

  def calc_velocity(true, false, forward_speed, _back_speed), do: forward_speed
  def calc_velocity(false, true, _forward_speed, back_speed), do: -back_speed
  def calc_velocity(_forward, _back, _forward_speed, _back_speed), do: 0.0

  def calc_angular_velocity(true, false, angular_speed), do: angular_speed
  def calc_angular_velocity(false, true, angular_speed), do: -angular_speed
  def calc_angular_velocity(_left, _right, _angular_speed), do: 0.0

end
