defmodule Tanx.Game do
  #### Public API

  @untitled_game_name "(Untitled Game)"

  require Logger

  def create(opts \\ []) do
    {game_opts, process_opts} = split_opts(opts)
    GenServer.start(__MODULE__, {game_opts}, process_opts)
  end

  def start(data, opts \\ []) do
    {game_opts, process_opts} = split_opts(opts)
    GenServer.start(__MODULE__, {data, game_opts}, process_opts)
  end

  def start_link(data, opts \\ []) do
    {game_opts, process_opts} = split_opts(opts)
    GenServer.start_link(__MODULE__, {data, game_opts}, process_opts)
  end

  def startup(game, data) do
    GenServer.call(game, {:startup, data})
  end

  def get_view(game, view_context) do
    GenServer.call(game, {:view, view_context})
  end

  def get_meta(game) do
    GenServer.call(game, {:meta})
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
    updater = GenServer.call(game, :get_updater_pid)
    GenServer.call(updater, :terminate)
    GenServer.call(game, :terminate)
  end

  defmodule Meta do
    defstruct(
      id: nil,
      state: :init,
      display_name: "",
      node: nil,
      data: nil
    )
  end

  defp split_opts(opts) do
    Keyword.split(opts, [
      :game_id,
      :display_name,
      :interval,
      :time_config,
      :rand_seed,
      :id_strategy
    ])
  end

  #### GenServer callbacks

  use GenServer

  defmodule State do
    defstruct(
      state: nil,
      opts: [],
      meta: %Tanx.Game.Meta{},
      data: nil,
      arena: nil,
      updater: nil,
      commands: [],
      callbacks: %{},
      time: 0
    )
  end

  alias Tanx.Game.Variant

  def init({opts}) do
    {:ok, do_init(opts)}
  end

  def init({data, opts}) do
    {:ok, do_init(opts) |> do_startup(data)}
  end

  def handle_call({:startup, _data}, _from, %State{state: :running} = state) do
    {:reply, {:error, :already_running}, state}
  end

  def handle_call({:startup, data}, _from, state) do
    {:reply, :ok, do_startup(state, data)}
  end

  def handle_call(:get_commands, _from, state) do
    {:reply, List.flatten(state.commands), %State{state | commands: []}}
  end

  def handle_call({:view, _view_context}, _from, %State{state: :init} = state) do
    {:reply, {:error, :not_running}, state}
  end

  def handle_call({:view, view_context}, _from, state) do
    view = Variant.view(state.data, state.arena, state.time, view_context)
    {:reply, view, state}
  end

  def handle_call({:meta}, _from, state) do
    {:reply, {:ok, state.meta}, state}
  end

  def handle_call({:control, _control_params}, _from, %State{state: :init} = state) do
    {:reply, {:error, :not_running}, state}
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

  def handle_call(:get_updater_pid, _from, state) do
    {:reply, state.updater, state}
  end

  def handle_call(:terminate, _from, state) do
    notification_data = Variant.stop(state.data, state.arena, state.time)

    notification = %Tanx.Game.Notifications.Ended{
      id: state.meta.id,
      time: state.time,
      data: notification_data
    }

    send_notifications([notification], state.callbacks)
    {:stop, :normal, :ok, state}
  end

  def handle_call({:start_handoff, on_node}, _from, state) do
    if on_node == Node.self() do
      Swarm.Tracker.handoff(state.meta.id, state)
    end

    {:reply, :ok, state}
  end

  def handle_cast({:swarm, :end_handoff, state}, _base_state) do
    {:noreply, do_handoff(state)}
  end

  def handle_info({:swarm, :die}, state) do
    if state.updater != nil, do: send(state.updater, {:swarm, :die})
    {:stop, :shutdown, state}
  end

  def handle_info(request, state), do: super(request, state)

  defp do_init(opts) do
    rand_seed = Keyword.get(opts, :rand_seed, nil)

    if rand_seed != nil do
      :rand.seed(:exrop, rand_seed)
    end

    id_strategy = Keyword.get(opts, :id_strategy, :random)
    Tanx.Util.ID.set_strategy(id_strategy)

    game_id = Keyword.get(opts, :game_id)
    display_name = Keyword.get(opts, :display_name, @untitled_game_name)
    meta = %Tanx.Game.Meta{id: game_id, display_name: display_name, node: Node.self()}

    %State{
      state: :init,
      opts: opts,
      meta: meta
    }
  end

  defp do_startup(base_state, data) do
    opts = base_state.opts
    time_config = Keyword.get(opts, :time_config, Tanx.Util.SystemTime.cur_offset())
    opts = Keyword.put(opts, :time_config, time_config)
    time = Tanx.Util.SystemTime.get(time_config)
    arena = Variant.init_arena(data, time)
    start_event = %Tanx.Game.Events.ArenaUpdated{time: time, arena: arena}
    {:ok, updater} = Tanx.Game.Updater.start_link(self(), arena, opts)
    {data, commands, _notifications} = Variant.event(data, start_event)
    meta = %Tanx.Game.Meta{base_state.meta | state: :running}

    %State{
      base_state
      | state: :running,
        opts: opts,
        meta: meta,
        data: data,
        arena: arena,
        updater: updater,
        commands: commands,
        time: time
    }
  end

  defp do_handoff(state) do
    opts =
      Keyword.update!(state.opts, :time_config, fn
        tc when is_integer(tc) -> Tanx.Util.SystemTime.updated_offset(state.time)
        tc -> tc
      end)

    from_node = state.meta.node
    meta = %Tanx.Game.Meta{state.meta | node: Node.self()}
    {:ok, updater} = Tanx.Game.Updater.start_link(self(), state.arena, opts)

    notification = %Tanx.Game.Notifications.Moved{
      id: meta.id,
      time: state.time,
      from_node: from_node,
      to_node: Node.self()
    }

    send_notifications([notification], state.callbacks)
    %State{state | updater: updater, opts: opts, meta: meta}
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
