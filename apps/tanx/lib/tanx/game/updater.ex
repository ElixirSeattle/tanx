defmodule Tanx.Game.Updater do
  def start_link(name) do
    GenServer.start_link(__MODULE__, {}, name: name)
  end

  use GenServer

  def child_spec(name) do
    %{
      id: name,
      start: {__MODULE__, :start_link, [name]}
    }
  end

  require Logger

  defmodule InternalData do
    defstruct(decomposed_walls: [])
  end

  defmodule State do
    defstruct(
      running: false,
      game: nil,
      arena: nil,
      internal: nil,
      interval: nil,
      time_config: nil,
      time: 0.0
    )
  end

  def init({}) do
    Logger.info("**** Init updater process #{inspect(self())}")
    {:ok, %State{}}
  end

  def handle_cast({:up, game, arena, opts}, _old_state) do
    Logger.info("**** Up updater process #{inspect(self())} from #{inspect(game)}")

    interval = Keyword.get(opts, :interval, 0.02)
    time_config = Keyword.get(opts, :time_config, nil)
    rand_seed = Keyword.get(opts, :rand_seed, nil)
    id_strategy = Keyword.get(opts, :id_strategy, :random)

    if rand_seed != nil do
      :rand.seed(:exrop, rand_seed)
    end

    Tanx.Util.ID.set_strategy(id_strategy)

    internal = %InternalData{
      decomposed_walls: Enum.map(arena.walls, &Tanx.Game.Walls.decompose_wall/1)
    }

    state = %State{
      running: true,
      game: game,
      arena: arena,
      internal: internal,
      interval: interval,
      time_config: time_config,
      time: Tanx.Util.SystemTime.get(time_config)
    }

    {:noreply, state, next_tick_timeout(state)}
  end

  def handle_cast({:down}, _old_state) do
    Logger.info("**** Down updater process #{inspect(self())}")
    {:noreply, %State{running: false}}
  end

  def handle_cast(:update, state) do
    state = perform_update(state)
    {:noreply, state, next_tick_timeout(state)}
  end

  def handle_info(:timeout, state) do
    state = perform_update(state)
    {:noreply, state, next_tick_timeout(state)}
  end

  def handle_info(request, state) do
    Logger.warn("Unexpected message: #{inspect(request)}")
    {:noreply, state}
  end

  defp perform_update(%State{running: false} = state), do: state

  defp perform_update(state) do
    cur = Tanx.Util.SystemTime.get(state.time_config)
    commands = GenServer.call(state.game, :get_commands)

    {arena, internal, events} =
      Enum.reduce(commands, {state.arena, state.internal, []}, fn cmd, {a, p, e} ->
        {a, p, more_e} = Tanx.Game.CommandHandler.handle(cmd, a, p, cur)
        {a, p, [more_e | e]}
      end)

    {arena, internal, more_events} = Tanx.Game.Step.update(arena, internal, cur - state.time)
    events = List.flatten([more_events | events])
    GenServer.call(state.game, {:update, cur, arena, events})
    %State{state | arena: arena, internal: internal, time: cur}
  end

  defp next_tick_timeout(state) do
    if state.interval == nil do
      :infinity
    else
      timeout_secs =
        max(state.time + state.interval - Tanx.Util.SystemTime.get(state.time_config), 0.0)

      trunc(timeout_secs * 1000)
    end
  end
end
