defmodule Tanx.PowerupUpdateTest do
  use ExUnit.Case

  setup do
    time_config = Tanx.SystemTime.new_config
    {:ok, game} = Tanx.Game.start_link(clock_interval: nil, time_config: time_config)
    {:ok, player} = game |> Tanx.Game.connect(name: "Ben")
    :ok = player |> Tanx.Player.new_tank()
    {:ok, game: game, time_config: time_config, player: player}
  end

  test "powerup created", %{game: game, player: player} do
    game_state = game |> Tanx.Game.get_state
    _powerup = Tanx.ArenaObjects.create_power_up(game_state.arena_objects, {0.1, 1.0})
    :ok = game |> Tanx.Game.manual_clock_tick(1000)
    want = %Tanx.View.PowerUp{x: 0.1, y: 1.0, radius: 0.4, type: %Tanx.PowerUpTypes.BouncingMissile{}}
    view = player |> Tanx.Player.view_arena_objects()
    assert view.powerups |> hd() == want
  end

  test "destroyed tank creates powerup", %{game: game, time_config: time_conf, player: player1} do
    #move the player forward
    :ok = player1 |> Tanx.Player.control_tank(:forward, true)
    time_conf |> Tanx.SystemTime.set(1000)
    :ok = game |> Tanx.Game.manual_clock_tick(1000)
    #create a second player
    {:ok, player2} = game |> Tanx.Game.connect(name: "greg")
    :ok = player2 |> Tanx.Player.new_tank()
    :ok = time_conf |> Tanx.SystemTime.set(3000)
    :ok = game |> Tanx.Game.manual_clock_tick(3000)

    #player one stops moving forward
    :ok = player1 |> Tanx.Player.control_tank(:forward, false)
    #player 2 shoots at player 1
    assert :ok == player2 |> Tanx.Player.new_missile()
    :ok = time_conf |> Tanx.SystemTime.set(3500)
    :ok = game |> Tanx.Game.manual_clock_tick(3500)
    assert :ok == player2 |> Tanx.Player.new_missile()
    :ok = time_conf |> Tanx.SystemTime.set(4000)
    :ok = game |> Tanx.Game.manual_clock_tick(4000)
    assert :ok == player2 |> Tanx.Player.new_missile()
    :ok = time_conf |> Tanx.SystemTime.set(5500)
    :ok = game |> Tanx.Game.manual_clock_tick(5500)
    #Check player 1 is destroyed and only 2 remains
    want = %Tanx.View.Tank{is_me: true,
                                name: "greg",
                                armor: 1.0,
                                x: 0.0,
                                y: 0.0,
                                heading: 0.0}
    view = player2 |> Tanx.Player.view_arena_objects()
    assert view.tanks |> hd() == want

    wanted_power_up = %Tanx.View.PowerUp{
      radius: 0.4,
      type: %Tanx.PowerUpTypes.BouncingMissile{
        name: "Bouncing Missile"
      },
      x: 6.0,
      y: 0.0
    }
    assert view.powerups |> hd() == wanted_power_up
  end

  test "tank collects power up", %{game: game, time_config: time_conf, player: player} do
    game_state = game |> Tanx.Game.get_state
    _powerup = Tanx.ArenaObjects.create_power_up(game_state.arena_objects, {3.0, 0.0})
    :ok = game |> Tanx.Game.manual_clock_tick(1000)
    want = %Tanx.View.PowerUp{x: 3.0, y: 0.0, radius: 0.4, type: %Tanx.PowerUpTypes.BouncingMissile{}}
    view = player |> Tanx.Player.view_arena_objects()
    assert view.powerups |> hd() == want
    :ok = player |> Tanx.Player.control_tank(:forward, true)
    time_conf |> Tanx.SystemTime.set(2500)
    :ok = game |> Tanx.Game.manual_clock_tick(2500)
    view = player |> Tanx.Player.view_arena_objects()
    assert view.powerups == []
    player_powerups = player |> Tanx.Player.get_powerups()
    want = %{ wall_bounce: 1 }
    assert player_powerups == want
  end

  test "player missile death removes power up from player", %{game: game, time_config: time_conf, player: player1} do
    :ok = game |> Tanx.Game.manual_clock_tick(1000)
    {:ok, power_up_pid} = Tanx.PowerUp.start_link(6.0, 0.0,
                                                       %Tanx.PowerUpTypes.BouncingMissile{})
    power_up_state = power_up_pid |> Tanx.PowerUp.get_state()
    assert :ok == player1 |> Tanx.Player.addPowerUp(power_up_state.type)
    player_powerups = player1 |> Tanx.Player.get_powerups()
    want = %{ wall_bounce: 1 }
    assert player_powerups == want
    assert :ok == player1 |> Tanx.Player.control_tank(:forward, true)
    assert :ok == game |> Tanx.Game.manual_clock_tick(2500)

    :ok = time_conf |> Tanx.SystemTime.set(3000)
    :ok = game |> Tanx.Game.manual_clock_tick(3000)

    #player one stops moving forward
    :ok = player1 |> Tanx.Player.control_tank(:forward, false)
    #create player 2
    {:ok, player2} = game |> Tanx.Game.connect(name: "greg")
    :ok = player2 |> Tanx.Player.new_tank()
    :ok = game |> Tanx.Game.manual_clock_tick(3300)

    #player 2 shoots at player 1
    assert :ok == player2 |> Tanx.Player.new_missile()
    :ok = time_conf |> Tanx.SystemTime.set(3625)
    :ok = game |> Tanx.Game.manual_clock_tick(3625)
    assert :ok == player2 |> Tanx.Player.new_missile()
    :ok = time_conf |> Tanx.SystemTime.set(3975)
    :ok = game |> Tanx.Game.manual_clock_tick(3975)

    :ok = game |> Tanx.Game.manual_clock_tick(9000)

    want_tanks = %Tanx.View.Tank{armor: 1.0, heading: 0.0, is_me: false,
         max_armor: 1.0, name: "greg", radius: 0.5, tread: 0.0, x: 0.0, y: 0.0}

    view = player1 |> Tanx.Player.view_arena_objects()
    assert view.tanks |> hd() == want_tanks
    :ok = player1 |> Tanx.Player.new_tank()

    player_powerups = player1 |> Tanx.Player.get_powerups()
    want = %{wall_bounce: 0}
    assert player_powerups == want
  end

  test "player self destruct removes power up from player", %{game: game, time_config: time_conf, player: player1} do
    :ok = game |> Tanx.Game.manual_clock_tick(1000)
    {:ok, power_up_pid} = Tanx.PowerUp.start_link(6.0, 0.0,
                                                       %Tanx.PowerUpTypes.BouncingMissile{})
    power_up_state = power_up_pid |> Tanx.PowerUp.get_state()
    assert :ok == player1 |> Tanx.Player.addPowerUp(power_up_state.type)
    player_powerups = player1 |> Tanx.Player.get_powerups()
    want = %{ wall_bounce: 1 }
    assert player_powerups == want
    player1 |> Tanx.Player.self_destruct_tank()
    player_powerups = player1 |> Tanx.Player.get_powerups()
    want = %{wall_bounce: 0}
    assert player_powerups == want
  end

  test "pick random powerup" do
    list = [:one, :two, :three]
    ret = Tanx.PowerUp.pick_power_up_type(list)
    assert is_atom ret
  end
end