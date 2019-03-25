defmodule Tanx.Handoff.Impl do
  require Logger

  defmodule State do
    @moduledoc false
    defstruct name: nil,
              nodes: MapSet.new(),
              processes_updated_counter: 0,
              processes_updated_at: 0,
              ets_table: nil,
              requests: %{}
  end

  @spec child_spec(options :: list()) :: Supervisor.child_spec()
  def child_spec(options \\ []) do
    %{
      id: Keyword.get(options, :name, __MODULE__),
      start: {__MODULE__, :start_link, [options]}
    }
  end

  @spec start_link(options :: list()) :: GenServer.on_start()
  def start_link(options \\ []) do
    name = Keyword.get(options, :name)

    if !is_atom(name) || is_nil(name) do
      raise ArgumentError, "expected :name to be given and to be an atom, got: #{inspect(name)}"
    end

    GenServer.start_link(__MODULE__, options, name: name)
  end

  ### GenServer callbacks

  def init(opts) do
    {:ok, opts} =
      case Keyword.get(opts, :init_module) do
        nil -> {:ok, opts}
        module -> module.init(opts)
      end

    Process.flag(:trap_exit, true)

    name = Keyword.get(opts, :name)

    Logger.info("Starting #{inspect(__MODULE__)} with name #{inspect(name)}")

    unless is_atom(name) do
      raise ArgumentError, "expected :name to be given and to be an atom, got: #{inspect(name)}"
    end

    :ets.new(name, [:named_table, {:read_concurrency, true}])

    state = %State{
      name: name,
      ets_table: name
    }

    state =
      case Keyword.get(opts, :members) do
        nil ->
          state

        members ->
          members = Enum.map(members, &fully_qualified_name/1)

          Enum.each(members, fn member ->
            DeltaCrdt.mutate_async(members_crdt_name(state.name), :add, [member, 1])
          end)

          neighbours = members -- [fully_qualified_name(state.name)]

          send(members_crdt_name(state.name), {:set_neighbours, members_crdt_names(neighbours)})
          send(handoff_crdt_name(state.name), {:set_neighbours, handoff_crdt_names(neighbours)})
          %{state | nodes: Enum.map(members, fn {_name, node} -> node end) |> MapSet.new()}
      end

    {:ok, state}
  end

  def handle_info({:handoff_updated, reply_to}, state) do
    handoff_data = DeltaCrdt.read(handoff_crdt_name(state.name), 30_000)

    Enum.each(:ets.match(state.ets_table, {:"$1", :_}), fn [key] ->
      if !Map.has_key?(handoff_data, key) do
        :ets.delete(state.ets_table, key)
      end
    end)
    :ets.insert(state.ets_table, Map.to_list(handoff_data))

    GenServer.reply(reply_to, :ok)

    requests =
      state.requests
      |> Enum.filter(fn {name, {pid, message}} ->
        case Map.get(handoff_data, name) do
          nil ->
            true

          data ->
            send(pid, {message, data})
            Logger.info("**** Handoff sending message for: #{inspect(name)}")

            DeltaCrdt.mutate_async(members_crdt_name(state.name), :remove, [name])

            :ets.delete(state.ets_table, name)
            false
        end
      end)
      |> Enum.into(%{})

    state = %State{state | requests: requests}

    {:noreply, state}
  end

  def handle_info({:members_updated, reply_to}, state) do
    members = Map.keys(DeltaCrdt.read(members_crdt_name(state.name), 30_000))

    members = members -- [state.name]

    new_nodes = Enum.map(members, fn {_name, node} -> node end) |> MapSet.new()

    send(members_crdt_name(state.name), {:set_neighbours, members_crdt_names(members)})
    send(handoff_crdt_name(state.name), {:set_neighbours, handoff_crdt_names(members)})

    GenServer.reply(reply_to, :ok)

    {:noreply, %{state | nodes: new_nodes}}
  end

  def handle_info({:EXIT, _pid, reason}, state) do
    {:stop, reason, state}
  end

  def handle_call({:set_members, members}, _from, state) do
    existing_members = MapSet.new(Map.keys(DeltaCrdt.read(members_crdt_name(state.name))))
    new_members = MapSet.new(member_names(members))

    Enum.each(MapSet.difference(existing_members, new_members), fn removed_member ->
      DeltaCrdt.mutate_async(members_crdt_name(state.name), :remove, [removed_member])
    end)

    Enum.each(MapSet.difference(new_members, existing_members), fn added_member ->
      DeltaCrdt.mutate_async(members_crdt_name(state.name), :add, [added_member, 1])
    end)

    neighbours = MapSet.difference(new_members, MapSet.new([state.name]))

    send(members_crdt_name(state.name), {:set_neighbours, members_crdt_names(neighbours)})
    send(handoff_crdt_name(state.name), {:set_neighbours, handoff_crdt_names(neighbours)})

    {:reply, :ok, state}
  end

  def handle_call(:get_handoff_ets_table, _from, %{ets_table: t} = state),
    do: {:reply, t, state}

  def handle_call({:request, name, message, pid}, _from, state) do
    case :ets.lookup(state.ets_table, name) do
      [{^name, data}] ->
        GenServer.cast(
          state.processes_pid,
          {:operation, {:remove, [name]}}
        )

        Logger.info("**** Handoff fulfilling request for: #{inspect(name)}")
        DeltaCrdt.mutate_async(handoff_crdt_name(state.name), :remove, [name])
        :ets.delete(state.ets_table, name)
        {:reply, {:ok, :data, data}, state}

      _ ->
        Logger.info("**** Handoff deferring request for: #{inspect(name)}")
        requests = Map.put(state.requests, name, {pid, message})
        {:reply, {:ok, :requested}, %State{state | requests: requests}}
    end
  end

  def handle_call({:unrequest, name}, _from, state) do
    requests = Map.delete(state.requests, name)
    {:reply, :ok, %State{state | requests: requests}}
  end

  def handle_call({:store, name, data}, _from, state) do
    Logger.info("**** Handoff storing data for: #{inspect(name)}")
    case Map.get(state.requests, name) do
      nil ->
        GenServer.call(
          state.processes_pid,
          {:operation, {:add, [name, data]}}
        )

        DeltaCrdt.mutate_async(handoff_crdt_name(state.name), :add, [name, data])
        :ets.insert(state.ets_table, {name, data})

      {pid, message} ->
        send(pid, {message, data})
    end

    {:reply, :ok, state}
  end

  defp member_names(names) do
    Enum.map(names, fn
      {name, node} -> {name, node}
      name when is_atom(name) -> {name, node()}
    end)
  end

  defp members_crdt_names(names) do
    Enum.map(names, fn {name, node} -> {members_crdt_name(name), node} end)
  end

  defp handoff_crdt_names(names) do
    Enum.map(names, fn {name, node} -> {handoff_crdt_name(name), node} end)
  end

  defp members_crdt_name(name), do: :"#{name}.MembersCrdt"
  defp handoff_crdt_name(name), do: :"#{name}.HandoffCrdt"

  defp fully_qualified_name({name, node}) when is_atom(name) and is_atom(node), do: {name, node}
  defp fully_qualified_name(name) when is_atom(name), do: {name, node()}
end
