defmodule Tanx.Game.Manager do
  def start_link(game_id, opts \\ []) do
    process_opts =
      case Keyword.fetch(opts, :game_address) do
        {:ok, addr} -> [name: addr]
        :error -> []
      end

    GenServer.start(__MODULE__, {game_id, opts}, process_opts)
  end

  use GenServer

  def child_spec({game_id, opts}) do
    %{
      id: Tanx.Game.manager_process_id(game_id),
      start: {__MODULE__, :start_link, [game_id, opts]}
    }
  end

  @untitled_game_name "(Untitled Game)"

  require Logger

  defmodule State do
    defstruct(
      game_id: nil,
      running: false,
      handoff: nil,
      opts: [],
      node: nil,
      display_name: "",
      data: nil,
      arena: nil,
      commands: [],
      sent_commands: [],
      callbacks: %{},
      time: 0.0
    )
  end

  def init({game_id, opts}) do
    Process.flag(:trap_exit, true)
    game_data = Keyword.get(opts, :game_data, nil)
    {:ok, do_init(game_id, opts) |> do_up(game_data)}
  end

  def handle_call({:up, _data}, _from, %State{running: true} = state) do
    {:reply, {:error, :already_running}, state}
  end

  def handle_call({:up, data}, _from, state) do
    {:reply, :ok, do_up(state, data)}
  end

  def handle_call({:down}, _from, %State{running: false} = state) do
    {:reply, {:error, :not_running}, state}
  end

  def handle_call({:down}, _from, state) do
    {:reply, :ok, do_down(state)}
  end

  def handle_call({:meta}, _from, state) do
    meta = %Tanx.Game.Meta{
      id: state.game_id,
      running: state.running,
      display_name: state.display_name,
      node: Node.self()
    }
    {:reply, {:ok, meta}, state}
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

  def handle_call({:control, _control_params}, _from, %State{running: false} = state) do
    {:reply, {:error, :not_running}, state}
  end

  def handle_call({:control, control_params}, _from, state) do
    {result, new_data, new_commands, notifications} =
      Tanx.Game.Variant.control(state.data, state.arena, state.time, control_params)

    send_notifications(notifications, state.callbacks)
    new_state = %State{state | data: new_data, commands: [new_commands | state.commands]}
    {:reply, result, new_state}
  end

  def handle_call(:get_commands, _from, %State{running: false} = state) do
    {:reply, [], state}
  end

  def handle_call(:get_commands, _from, state) do
    commands = List.flatten(state.commands ++ state.sent_commands)
    {:reply, commands, %State{state | commands: [], sent_commands: commands}}
  end

  def handle_call({:update, _time, _arena, _events}, _from, %State{running: false} = state) do
    {:reply, {:error, :not_running}, state}
  end

  def handle_call({:update, time, arena, events}, _from, state) do
    callbacks = state.callbacks
    update_event = %Tanx.Game.Events.ArenaUpdated{time: time, arena: arena}

    {new_data, new_commands} =
      [update_event | events]
      |> Enum.reduce({state.data, state.commands}, fn event, {data, commands} ->
        {ndata, command, notifications} = Tanx.Game.Variant.event(data, event)
        send_notifications(notifications, callbacks)
        {ndata, [command | commands]}
      end)

    new_state = %State{
      state
      | arena: arena,
        data: new_data,
        time: time,
        commands: new_commands,
        sent_commands: []
    }

    {:reply, :ok, new_state}
  end

  def handle_info({:receive_handoff, _data}, %State{running: true} = state) do
    {:noreply, state}
  end

  def handle_info({:receive_handoff, data}, base_state) do
    {:noreply, state_from_handoff(base_state, data)}
  end

  def handle_info({:EXIT, _pid, reason}, state) do
    {:stop, reason, state}
  end

  def handle_info(whatevah, state) do
    Logger.warn("Received unexpected message: #{inspect(whatevah)}")
    {:noreply, state}
  end

  def terminate(reason, state) do
    do_handoff(state)
    Logger.info("**** Terminate game process #{inspect(state.game_id)} due to #{inspect(reason)}")
    :ok
  end

  defp state_from_handoff(base_state, handoff_state) do
    opts =
      Keyword.update!(handoff_state.opts, :time_config, fn
        tc when is_integer(tc) -> Tanx.Util.SystemTime.updated_offset(handoff_state.time)
        tc -> tc
      end)

    GenServer.cast(Tanx.Game.updater_process_id(handoff_state.game_id), {:up, self(), handoff_state.arena, opts})

    notification = %Tanx.Game.Notifications.Moved{
      id: handoff_state.game_id,
      time: handoff_state.time,
      from_node: handoff_state.node,
      to_node: Node.self()
    }

    send_notifications([notification], handoff_state.callbacks)

    Logger.info("**** Received handoff for #{inspect(base_state.game_id)}")

    %State{handoff_state | handoff: base_state.handoff, opts: opts, node: Node.self()}
  end

  defp do_init(game_id, opts) do
    rand_seed = Keyword.get(opts, :rand_seed, nil)

    if rand_seed != nil do
      :rand.seed(:exrop, rand_seed)
    end

    id_strategy = Keyword.get(opts, :id_strategy, :random)
    Tanx.Util.ID.set_strategy(id_strategy)

    display_name = Keyword.get(opts, :display_name, @untitled_game_name)

    handoff = Keyword.get(opts, :handoff, nil)

    Logger.info("**** Init game process #{inspect(game_id)} #{inspect(self())}")

    %State{
      game_id: game_id,
      running: false,
      handoff: handoff,
      opts: opts,
      display_name: display_name,
      node: Node.self()
    }
  end

  defp do_up(%State{handoff: nil} = base_state, nil), do: base_state

  defp do_up(base_state, nil) do
    case Tanx.Util.Handoff.request(base_state.handoff, base_state.game_id, :receive_handoff) do
      {:ok, :requested} ->
        base_state

      {:ok, :data, data} ->
        state_from_handoff(base_state, data)
    end
  end

  defp do_up(base_state, data) do
    if base_state.handoff do
      Tanx.Util.Handoff.unrequest(base_state.handoff, base_state.game_id)
    end

    opts = base_state.opts
    time_config = Keyword.get(opts, :time_config, Tanx.Util.SystemTime.cur_offset())
    opts = Keyword.put(opts, :time_config, time_config)
    time = Tanx.Util.SystemTime.get(time_config)
    arena = Tanx.Game.Variant.init_arena(data, time)
    start_event = %Tanx.Game.Events.ArenaUpdated{time: time, arena: arena}
    GenServer.cast(Tanx.Game.updater_process_id(base_state.game_id), {:up, self(), arena, opts})
    {data, commands, _notifications} = Tanx.Game.Variant.event(data, start_event)

    Logger.info("**** Up game #{inspect(base_state.game_id)}")

    %State{
      base_state
      | running: true,
        opts: opts,
        data: data,
        arena: arena,
        commands: commands,
        time: time
    }
  end

  defp do_handoff(%State{running: false} = state), do: state

  defp do_handoff(state) do
    GenServer.cast(Tanx.Game.updater_process_id(state.game_id), {:down})

    if state.handoff do
      Tanx.Util.Handoff.store(state.handoff, state.game_id, state)
      Logger.info("**** Sent handoff for #{inspect(state.game_id)}")
    end

    down_state(state)
  end

  defp do_down(state) do
    GenServer.cast(Tanx.Game.updater_process_id(state.game_id), {:down})

    notification_data = Tanx.Game.Variant.stop(state.data, state.arena, state.time)

    notification = %Tanx.Game.Notifications.Ended{
      id: state.game_id,
      time: state.time,
      data: notification_data
    }

    send_notifications([notification], state.callbacks)
    Logger.info("**** Down game: #{inspect(state.game_id)}")

    down_state(state)
  end

  defp down_state(state) do
    %State{
      game_id: state.game_id,
      running: false,
      handoff: state.handoff,
      opts: state.opts,
      display_name: state.display_name,
      node: Node.self()
    }
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
