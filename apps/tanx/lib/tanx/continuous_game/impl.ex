defmodule Tanx.ContinuousGame.Impl do
  defstruct(
    maze: nil,
    time: nil,
    player_handles: %{},
    players: %{},
    player_id_map: %{}
  )
end


defimpl Tanx.Game.Variant, for: Tanx.ContinuousGame.Impl do

  @tank_starting_armor 2.0
  @tank_explosion_intensity 1.0
  @tank_explosion_radius 1.0
  @tank_explosion_length 0.6
  @missile_velocity 10.0
  @missile_impact_intensity 1.0
  @missile_explosion_intensity 0.25
  @missile_explosion_radius 0.5
  @missile_explosion_length 0.4
  @self_destruct_explosion_intensity 4.0
  @self_destruct_explosion_radius 2.5
  @self_destruct_explosion_length 1.0
  @power_up_lifetime 10.0

  alias Tanx.ContinuousGame.Impl
  alias Tanx.ContinuousGame.Player
  alias Tanx.ContinuousGame.PlayerPrivate
  alias Tanx.ContinuousGame.PlayersChanged

  def init_arena(data, _time) do
    arena = Tanx.ContinuousGame.Mazes.get(data.maze)
    %Tanx.Game.Arena{arena | tanks: %{}, missiles: %{}, explosions: %{}, power_ups: %{}}
  end

  def view(data, _arena, _time, {:players, player_handle}) do
    %Tanx.ContinuousGame.PlayerListView{
      players: data.players,
      cur_player: Map.get(data.player_handles, player_handle)
    }
  end

  def view(_data, arena, _time, :static) do
    %Tanx.ContinuousGame.StaticView{
      size: arena.size,
      walls: arena.walls,
      entry_points: arena.entry_points
    }
  end

  def view(data, arena, _time, {:arena, player_handle}) do
    %Tanx.ContinuousGame.ArenaView{
      entry_points: arena.entry_points,
      tanks: arena.tanks,
      missiles: arena.missiles,
      explosions: arena.explosions,
      power_ups: arena.power_ups,
      players: data.players,
      cur_player: Map.get(data.player_handles, player_handle)
    }
  end

  def control(data, {:add_player, name}) do
    player_handles = data.player_handles
    players = data.players
    player_handle = Tanx.Util.ID.create("H", player_handles, 8)
    player_id = Tanx.Util.ID.create("P", players)
    player = %Player{name: name, joined_at: data.time}
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

  def control(data, {:remove_player, player_handle}) do
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
            cmd = %Tanx.Game.Commands.DeleteTank{query: %{player_id: player_id},
              event_data: %{deleting_player_id: player_id}}
            {players, [cmd], []}
          id ->
            cmd = %Tanx.Game.Commands.DeleteTank{id: id, event_data: %{deleting_player_id: player_id}}
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

  def control(data, {:rename_player, player_handle, name}) do
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

  def control(data, {:start_tank, player_handle, entry_point_name}) do
    player_handles = data.player_handles
    if Map.has_key?(player_handles, player_handle) do
      player_private = Map.fetch!(player_handles, player_handle)
      tank_id = player_private.tank_id
      player_id = player_private.player_id
      case tank_id do
        nil ->
          new_player_private = %PlayerPrivate{player_private | tank_id: true}
          new_player_handles = Map.put(player_handles, player_handle, new_player_private)
          command = %Tanx.Game.Commands.CreateTank{
            entry_point_name: entry_point_name,
            armor: @tank_starting_armor,
            max_armor: @tank_starting_armor,
            explosion_intensity: @tank_explosion_intensity,
            explosion_radius: @tank_explosion_radius,
            explosion_length: @tank_explosion_length,
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

  def control(data, {:control_tank, player_handle, :fire, true}) do
    player_handles = data.player_handles
    if Map.has_key?(player_handles, player_handle) do
      player_private = Map.fetch!(player_handles, player_handle)
      tank_id = player_private.tank_id
      time = data.time
      reloaded_at = player_private.reloaded_at
      cond do
        reloaded_at > time ->
          {{:error, :tank_not_loaded, [time_needed: reloaded_at - time]},
            data, [], []}
        tank_id == nil || tank_id == true ->
          {{:error, :tank_not_found, [player_handle: player_handle]}, data, [], []}
        true ->
          command = %Tanx.Game.Commands.FireMissile{
            tank_id: tank_id,
            velocity: @missile_velocity,
            bounce: player_private.bounce,
            impact_intensity: @missile_impact_intensity,
            explosion_intensity: @missile_explosion_intensity,
            explosion_radius: @missile_explosion_radius,
            explosion_length: @missile_explosion_length,
            chain_data: %{originator_id: player_private.player_id}
          }
          new_player_private = %PlayerPrivate{player_private |
            reloaded_at: time + player_private.reload_length}
          new_player_handles = Map.put(player_handles, player_handle, new_player_private)
          {:ok, %Impl{data | player_handles: new_player_handles}, [command], []}
      end
    else
      {{:error, :player_not_found, [player_handle: player_handle]}, data, [], []}
    end
  end

  def control(data, {:control_tank, _player_handle, :fire, false}) do
    {:ok, data, [], []}
  end

  def control(data, {:control_tank, player_handle, button, is_down}) do
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
        command = %Tanx.Game.Commands.SetTankVelocity{
          id: tank_id, velocity: velocity, angular_velocity: angular_velocity
        }
        new_player_handles = Map.put(player_handles, player_handle, new_player_private)
        {:ok, %Impl{data | player_handles: new_player_handles}, [command], []}
      end
    else
      {{:error, :player_not_found, [player_handle: player_handle]}, data, [], []}
    end
  end

  def control(data, {:destruct_tank, player_handle}) do
    player_handles = data.player_handles
    if Map.has_key?(player_handles, player_handle) do
      player_private = Map.fetch!(player_handles, player_handle)
      tank_id = player_private.tank_id
      if tank_id == nil || tank_id == true do
        {{:error, :tank_not_found, [player_handle: player_handle]}, data, [], []}
      else
        command = %Tanx.Game.Commands.ExplodeTank{
          id: tank_id,
          explosion_intensity: @self_destruct_explosion_intensity,
          explosion_radius: @self_destruct_explosion_radius,
          explosion_length: @self_destruct_explosion_length,
          chain_data: %{originator_id: player_private.player_id}
        }
        {:ok, data, [command], []}
      end
    else
      {{:error, :player_not_found, [player_handle: player_handle]}, data, [], []}
    end
  end

  def event(data, %Tanx.Game.Events.ArenaUpdated{time: time}) do
    {%Impl{data | time: time}, [], []}
  end

  def event(data, %Tanx.Game.Events.TankCreated{id: tank_id, event_data: %{player_handle: player_handle}}) do
    player_handles = data.player_handles
    player_private = Map.fetch!(player_handles, player_handle)
    new_player_private = %PlayerPrivate{player_private | tank_id: tank_id}
    new_player_handles = Map.put(player_handles, player_handle, new_player_private)
    {%Impl{data | player_handles: new_player_handles}, [], []}
  end

  def event(data, %Tanx.Game.Events.TankDeleted{event_data: %{deleting_player_id: player_id}}) do
    new_players = Map.delete(data.players, player_id)
    notification = %PlayersChanged{players: new_players}
    {%Impl{data | players: new_players}, [], [notification]}
  end

  def event(data, %Tanx.Game.Events.TankDeleted{tank: tank, event_data: %{originator_id: originator_id}}) do
    owner_id = tank.data[:player_id]
    players = data.players
    player_id_map = data.player_id_map
    player_handles = data.player_handles
    if Map.has_key?(player_id_map, owner_id) do
      owner_handle = Map.fetch!(player_id_map, owner_id)
      owner_private = Map.fetch!(player_handles, owner_handle)
      new_owner_private = %PlayerPrivate{owner_private | tank_id: nil, bounce: 0}
      new_player_handles = Map.put(player_handles, owner_handle, new_owner_private)
      owner = Map.fetch!(players, owner_id)
      new_owner = %Player{owner | deaths: owner.deaths + 1}
      new_players = Map.put(players, owner_id, new_owner)
      new_players =
        if originator_id == owner_id do
          new_players
        else
          originator = Map.fetch!(new_players, originator_id)
          new_originator = %Player{originator | kills: originator.kills + 1}
          Map.put(new_players, originator_id, new_originator)
        end
      new_data = %Impl{data | player_handles: new_player_handles, players: new_players}
      cmd = create_random_powerup(tank.pos)
      notification = %PlayersChanged{players: new_players}
      {new_data, [cmd], [notification]}
    else
      {data, [], []}
    end
  end

  def event(data, %Tanx.Game.Events.PowerUpCollected{tank: tank, power_up: %Tanx.Game.Arena.PowerUp{data: %{type: :bounce}}}) do
    owner_id = tank.data[:player_id]
    player_id_map = data.player_id_map
    player_handles = data.player_handles
    if Map.has_key?(player_id_map, owner_id) do
      owner_handle = Map.fetch!(player_id_map, owner_id)
      owner_private = Map.fetch!(player_handles, owner_handle)
      new_owner_private = %PlayerPrivate{owner_private | bounce: 1}
      new_player_handles = Map.put(player_handles, owner_handle, new_owner_private)
      new_data = %Impl{data | player_handles: new_player_handles}
      {new_data, [], []}
    else
      {data, [], []}
    end
  end

  def event(data, _event) do
    {data, [], []}
  end

  def calc_velocity(true, false, forward_speed, _back_speed), do: forward_speed
  def calc_velocity(false, true, _forward_speed, back_speed), do: -back_speed
  def calc_velocity(_forward, _back, _forward_speed, _back_speed), do: 0.0

  def calc_angular_velocity(true, false, angular_speed), do: angular_speed
  def calc_angular_velocity(false, true, angular_speed), do: -angular_speed
  def calc_angular_velocity(_left, _right, _angular_speed), do: 0.0

  def create_random_powerup(pos) do
    case :rand.uniform(2) do
      1 -> create_health_powerup(pos)
      2 -> create_bounce_powerup(pos)
    end
  end

  def create_health_powerup(pos) do
    tank_modifier = fn (t, _p) ->
      %Tanx.Game.Arena.Tank{t | armor: min(t.max_armor, t.armor + 1.0)}
    end
    %Tanx.Game.Commands.CreatePowerUp{
      pos: pos,
      expires_in: @power_up_lifetime,
      tank_modifier: tank_modifier,
      data: %{type: :health}
    }
  end

  def create_bounce_powerup(pos) do
    %Tanx.Game.Commands.CreatePowerUp{
      pos: pos,
      expires_in: @power_up_lifetime,
      data: %{type: :bounce}
    }
  end

end
