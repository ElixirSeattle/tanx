defmodule Tanx.Game do
  #### Public API

  def start(data, opts \\ []) do
    {params, process_opts} = get_start_params(data, opts)
    GenServer.start(__MODULE__, params, process_opts)
  end

  def start_link(data, opts \\ []) do
    {params, process_opts} = get_start_params(data, opts)
    GenServer.start_link(__MODULE__, params, process_opts)
  end

  def get_view(game, view_context) do
    GenServer.call(game, {:view, view_context})
  end

  def control(game, params) do
    GenServer.call(game, {:control, params})
  end

  def add_callback(game, type, name \\ nil, callback) do
    GenServer.call(game, {:add_callback, type, name, callback})
  end

  def remove_callback(game, type, name) do
    GenServer.call(game, {:remove_callback, type, name})
  end

  def terminate(game) do
    GenServer.call(game, :terminate)
  end

  defp get_start_params(data, opts) do
    {game_opts, process_opts} =
      Keyword.split(opts, [:interval, :time_config, :rand_seed, :id_strategy])

    {{data, game_opts}, process_opts}
  end

  #### GenServer callbacks

  use GenServer

  defmodule State do
    defstruct(
      data: nil,
      arena: nil,
      updater: nil,
      commands: [],
      callbacks: %{},
      time: 0
    )
  end

  alias Tanx.Game.Variant

  def init({data, opts}) do
    time_config = Keyword.get(opts, :time_config, Tanx.Util.SystemTime.cur_offset())
    rand_seed = Keyword.get(opts, :rand_seed, nil)
    id_strategy = Keyword.get(opts, :id_strategy, :random)
    opts = Keyword.put(opts, :time_config, time_config)

    if rand_seed != nil do
      :rand.seed(:exrop, rand_seed)
    end

    Tanx.Util.ID.set_strategy(id_strategy)
    time = Tanx.Util.SystemTime.get(time_config)
    arena = Variant.init_arena(data, time)
    start_event = %Tanx.Game.Events.ArenaUpdated{time: time, arena: arena}
    updater = Tanx.Game.Updater.start_link(self(), arena, opts)
    {data, commands, _notifications} = Variant.event(data, start_event)

    state = %State{
      data: data,
      arena: arena,
      updater: updater,
      commands: commands,
      time: time
    }

    {:ok, state}
  end

  def handle_call(:get_commands, _from, state) do
    {:reply, List.flatten(state.commands), %State{state | commands: []}}
  end

  def handle_call({:view, view_context}, _from, state) do
    view = Variant.view(state.data, state.arena, state.time, view_context)
    {:reply, view, state}
  end

  def handle_call({:control, control_params}, _from, state) do
    {result, new_data, new_commands, notifications} = Variant.control(state.data, control_params)
    send_notifications(notifications, state.callbacks)
    new_state = %State{state | data: new_data, commands: [new_commands | state.commands]}
    {:reply, result, new_state}
  end

  def handle_call({:add_callback, type, name, callback}, _from, state) do
    type_callbacks = Map.get(state.callbacks, type, %{})

    name =
      if name == nil do
        Tanx.Util.ID.create("L", type_callbacks)
      else
        name
      end

    type_callbacks = Map.put(type_callbacks, name, callback)
    callbacks = Map.put(state.callbacks, type, type_callbacks)
    new_state = %State{state | callbacks: callbacks}
    {:reply, {:ok, name}, new_state}
  end

  def handle_call({:remove_callback, type, name}, _from, state) do
    type_callbacks =
      state.callbacks
      |> Map.get(type, %{})
      |> Map.delete(name)

    callbacks = Map.put(state.callbacks, type, type_callbacks)
    new_state = %State{state | callbacks: callbacks}
    {:reply, :ok, new_state}
  end

  def handle_call({:update, time, arena, events}, _from, state) do
    callbacks = state.callbacks
    update_event = %Tanx.Game.Events.ArenaUpdated{time: time, arena: arena}
    {data, commands, notifications} = Variant.event(state.data, update_event)
    all_commands = [commands | state.commands]
    send_notifications(notifications, callbacks)

    {data, all_commands} =
      Enum.reduce(events, {data, all_commands}, fn event, {d, c_acc} ->
        {d, c, n} = Variant.event(d, event)
        send_notifications(n, callbacks)
        {d, [c | c_acc]}
      end)

    new_state = %State{state | arena: arena, data: data, time: time, commands: all_commands}
    {:reply, :ok, new_state}
  end

  def handle_call(:terminate, _from, state) do
    {:stop, :normal, :ok, state}
  end

  defp send_notifications(notifications, callbacks) do
    Enum.each(notifications, fn notification ->
      callbacks
      |> Map.get(notification.__struct__, %{})
      |> Enum.each(fn {_name, callback} ->
        callback.(notification)
      end)
    end)
  end
end
