defmodule Tanx.Game.Updater do
  #### Public API

  def start_link(game, arena, opts \\ []) do
    GenServer.start_link(__MODULE__, {game, arena, opts})
  end

  #### GenServer callbacks

  use GenServer

  defmodule InternalData do
    defstruct(decomposed_walls: [])
  end

  defmodule State do
    defstruct(
      game: nil,
      arena: nil,
      internal: nil,
      interval: nil,
      time_config: nil,
      time: 0.0
    )
  end

  def init({game, arena, opts}) do
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
      game: game,
      arena: arena,
      internal: internal,
      interval: interval,
      time_config: time_config,
      time: Tanx.Util.SystemTime.get(time_config)
    }

    {:ok, state, next_tick_timeout(state)}
  end

  def handle_call(:terminate, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_cast(:update, state) do
    state = perform_update(state)
    {:noreply, state, next_tick_timeout(state)}
  end

  def handle_info(:timeout, state) do
    state = perform_update(state)
    {:noreply, state, next_tick_timeout(state)}
  end

  def handle_info(request, state), do: super(request, state)

  #### Logic

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
