defmodule Tanx.Game.CommandHandlerTest do
  use ExUnit.Case

  setup do
    :rand.seed(:exrop, {1, 2, 3})
    Tanx.Util.ID.set_strategy(:sequential)
    :ok
  end

  describe "Defer" do
    test "defer an event" do
      command = %Tanx.Game.Commands.Defer{event: "hello"}
      result = Tanx.Game.CommandHandler.handle(command, :arena, :internal, nil)
      assert result == {:arena, :internal, ["hello"]}
    end
  end

  describe "CreateTank" do
    setup do
      command = %Tanx.Game.Commands.CreateTank{
        entry_point_name: "epn",
        radius: 1.1,
        collision_radius: 1.2,
        armor: 1.3,
        max_armor: 1.4,
        explosion_intensity: 1.5,
        explosion_radius: 1.6,
        explosion_length: 1.7,
        data: "hi"
      }

      entry_point = %Tanx.Game.Arena.EntryPoint{
        pos: {-2, -3},
        heading: -1
      }

      initial_arena = %Tanx.Game.Arena{entry_points: %{"epn" => entry_point}}

      expected_tank = %Tanx.Game.Arena.Tank{
        pos: {-2, -3},
        radius: 1.1,
        collision_radius: 1.2,
        heading: -1,
        armor: 1.3,
        max_armor: 1.4,
        explosion_intensity: 1.5,
        explosion_radius: 1.6,
        explosion_length: 1.7,
        data: "hi"
      }

      expected_entry_point = %Tanx.Game.Arena.EntryPoint{entry_point | available: false}

      expected_arena = %Tanx.Game.Arena{
        entry_points: %{"epn" => expected_entry_point},
        tanks: %{"T1" => expected_tank}
      }

      {:ok,
       [
         command: command,
         initial_arena: initial_arena,
         expected_tank: expected_tank,
         expected_arena: expected_arena
       ]}
    end

    test "create a tank without event data", context do
      result =
        Tanx.Game.CommandHandler.handle(
          context[:command],
          context[:initial_arena],
          :internal,
          nil
        )

      assert result == {context[:expected_arena], :internal, []}
    end

    test "create a tank with event data", context do
      command = %Tanx.Game.Commands.CreateTank{context[:command] | event_data: "ho"}

      expected_event = %Tanx.Game.Events.TankCreated{
        id: "T1",
        tank: context[:expected_tank],
        event_data: "ho"
      }

      result = Tanx.Game.CommandHandler.handle(command, context[:initial_arena], :internal, nil)
      assert result == {context[:expected_arena], :internal, [expected_event]}
    end

    test "create a tank on an unavailable entry point", context do
      entry_point = %Tanx.Game.Arena.EntryPoint{available: false}
      initial_arena = %Tanx.Game.Arena{entry_points: %{"epn" => entry_point}}
      result = Tanx.Game.CommandHandler.handle(context[:command], initial_arena, :internal, nil)
      assert result == {initial_arena, :internal, []}
    end
  end

  describe "DeleteTank" do
    setup do
      tank1 = %Tanx.Game.Arena.Tank{
        data: "tank1"
      }

      tank2 = %Tanx.Game.Arena.Tank{
        data: "tank2"
      }

      initial_arena = %Tanx.Game.Arena{
        tanks: %{"T1" => tank1, "T2" => tank2}
      }

      {:ok, [tank1: tank1, tank2: tank2, initial_arena: initial_arena]}
    end

    test "delete a tank by ID", context do
      command = %Tanx.Game.Commands.DeleteTank{id: "T1"}
      initial_arena = context[:initial_arena]

      expected_arena = %Tanx.Game.Arena{
        initial_arena
        | tanks: Map.delete(initial_arena.tanks, "T1")
      }

      result = Tanx.Game.CommandHandler.handle(command, initial_arena, :internal, nil)
      assert result == {expected_arena, :internal, []}
    end

    test "delete a tank by ID with event", context do
      command = %Tanx.Game.Commands.DeleteTank{id: "T1", event_data: "ho"}
      initial_arena = context[:initial_arena]

      expected_arena = %Tanx.Game.Arena{
        initial_arena
        | tanks: Map.delete(initial_arena.tanks, "T1")
      }

      expected_event = %Tanx.Game.Events.TankDeleted{
        id: "T1",
        tank: context[:tank1],
        event_data: "ho"
      }

      result = Tanx.Game.CommandHandler.handle(command, initial_arena, :internal, nil)
      assert result == {expected_arena, :internal, [expected_event]}
    end

    test "delete a tank by query term with event", context do
      command = %Tanx.Game.Commands.DeleteTank{query: "tank2", event_data: "ho"}
      initial_arena = context[:initial_arena]

      expected_arena = %Tanx.Game.Arena{
        initial_arena
        | tanks: Map.delete(initial_arena.tanks, "T2")
      }

      expected_event = %Tanx.Game.Events.TankDeleted{
        id: "T2",
        tank: context[:tank2],
        event_data: "ho"
      }

      result = Tanx.Game.CommandHandler.handle(command, initial_arena, :internal, nil)
      assert result == {expected_arena, :internal, [expected_event]}
    end

    test "delete a tank by query function", context do
      command = %Tanx.Game.Commands.DeleteTank{query: &String.starts_with?(&1.data, "tank")}
      initial_arena = context[:initial_arena]
      expected_arena = %Tanx.Game.Arena{}

      result = Tanx.Game.CommandHandler.handle(command, initial_arena, :internal, nil)
      assert result == {expected_arena, :internal, []}
    end
  end

  describe "SetTankVelocity" do
    # TODO
  end

  describe "ExplodeTank" do
    # TODO
  end

  describe "FireMissile" do
    # TODO
  end

  describe "CreatePowerUp" do
    # TODO
  end
end
