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
        tanks: %{"T00000000" => expected_tank}
      }

      {:ok, [
        command: command,
        initial_arena: initial_arena,
        expected_tank: expected_tank,
        expected_arena: expected_arena
      ]}
    end

    test "create a tank without event data", context do
      result = Tanx.Game.CommandHandler.handle(
        context[:command], context[:initial_arena], :internal, nil)
      assert result == {context[:expected_arena], :internal, []}
    end

    test "create a tank with event data", context do
      command = %Tanx.Game.Commands.CreateTank{context[:command] | event_data: "ho"}
      expected_event = %Tanx.Game.Events.TankCreated{
        id: "T00000000", tank: context[:expected_tank], event_data: "ho"}

      result = Tanx.Game.CommandHandler.handle(command, context[:initial_arena], :internal, nil)
      assert result == {context[:expected_arena], :internal, [expected_event]}
    end

    test "create a tank on an unavailable entry point", context do
      entry_point = %Tanx.Game.Arena.EntryPoint{available: false}
      initial_arena = %Tanx.Game.Arena{entry_points: %{"epn" => entry_point}}
      result = Tanx.Game.CommandHandler.handle(
        context[:command], initial_arena, :internal, nil)
      assert result == {initial_arena, :internal, []}
    end

  end

end
