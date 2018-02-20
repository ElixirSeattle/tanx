defmodule Tanx.Game do

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

  def add_listener(game, type, listener) do
    GenServer.call(game, {:add_listener, type, listener})
  end

  defp get_start_params(data, opts) do
    {game_opts, process_opts} = Keyword.split(opts, [:interval, :time_config])
    {{data, game_opts}, process_opts}
  end


  use GenServer

  defmodule State do
    defstruct(
      data: nil,
      arena: nil,
      updater: nil,
      commands: [],
      listeners: %{},
      time: 0
    )
  end

  def init({data, game_opts}) do
    time_config = Keyword.get(game_opts, :time_config, nil)
    time = Tanx.Util.SystemTime.get(time_config)
    arena = Tanx.Game.Variant.init_arena(data, time)
    updater = Tanx.Updater.Process.start_link(self(), arena, game_opts)
    state = %State{
      data: data,
      arena: arena,
      updater: updater,
      time: time
    }
    {:ok, state}
  end

  def handle_call(:get_commands, _from, state) do
    {:reply, state.commands, %State{state | commands: []}}
  end

  def handle_call({:view, view_context}, _from, state) do
    view = Tanx.Game.Variant.view(state.data, state.time, state.arena, view_context)
    {:reply, view, state}
  end

  def handle_call({:control, control_params}, _from, state) do
    {result, new_data, new_commands, notifications} =
      Tanx.Game.Variant.control(state.data, state.time, state.arena, control_params)
    send_notifications(notifications, state.listeners)
    new_state = %State{state | data: new_data, commands: state.commands ++ new_commands}
    {:reply, result, new_state}
  end

  def handle_call({:add_listener, type, listener}, _from, state) do
    type_listeners = Map.get(state.listeners, type, [])
    type_listeners = [listener | type_listeners]
    listeners = Map.put(state.listeners, type, type_listeners)
    new_state = %State{state | listeners: listeners}
    {:reply, :ok, new_state}
  end

  def handle_call({:update, time, arena, events}, _from, state) do
    new_data = Enum.reduce(events, state.data, fn event, data ->
      {d, n} = Tanx.Game.Variant.event(data, time, arena, event)
      send_notifications(n, state.listeners)
      d
    end)

    new_state = %State{state | arena: arena, data: new_data, time: time}
    {:reply, :ok, new_state}
  end

  defp send_notifications(notifications, listeners) do
    Enum.each(notifications, fn notification ->
      listeners
      |> Map.get(notification.__struct__, [])
      |> Enum.each(fn listener ->
        listener.(notification)
      end)
    end)
  end

end


defprotocol Tanx.Game.Variant do
  def init_arena(data, time)
  def view(data, time, arena, view_context)
  def control(data, time, arena, params)
  def event(data, time, arena, event)
end
