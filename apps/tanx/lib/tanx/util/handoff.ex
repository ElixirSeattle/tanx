defmodule Tanx.Util.Handoff do
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def stop(handoff, reason \\ :normal, timeout \\ 5000) do
    GenServer.stop(handoff, reason, timeout)
  end

  def request(handoff, name, message, pid \\ self()) do
    GenServer.call(handoff, {:request, name, message, pid})
  end

  def unrequest(handoff, name) do
    GenServer.call(handoff, {:unrequest, name})
  end

  def store(handoff, name, data) do
    GenServer.cast(handoff, {:store, name, data})
  end

  use GenServer

  require Logger

  defmodule State do
    @moduledoc false
    defstruct node_id: nil,
              members_pid: nil,
              members: %{},
              processes_pid: nil,
              ets_table: nil,
              requests: %{}
  end

  def child_spec(opts \\ []) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def init(opts) do
    Process.flag(:trap_exit, true)

    node_id = generate_node_id()

    {:ok, members_pid} =
      DeltaCrdt.CausalCrdt.start_link(
        DeltaCrdt.AWLWWMap,
        notify: {self(), :members_updated},
        sync_interval: 5,
        ship_interval: 5,
        ship_debounce: 1
      )

    {:ok, processes_pid} =
      DeltaCrdt.CausalCrdt.start_link(
        DeltaCrdt.AWLWWMap,
        sync_interval: 5,
        ship_interval: 50,
        ship_debounce: 100,
        notify: {self(), :processes_updated}
      )

    name = Keyword.get(opts, :name)

    :ets.new(name, [:named_table, {:read_concurrency, true}])

    GenServer.cast(
      members_pid,
      {:operation, {:add, [node_id, {members_pid, processes_pid}]}}
    )

    {:ok,
     %State{
       node_id: node_id,
       members_pid: members_pid,
       processes_pid: processes_pid,
       ets_table: name
     }}
  end

  def handle_call({:join_hordes, other_horde}, from, state) do
    GenServer.cast(
      other_horde,
      {:request_to_join_hordes, {state.node_id, state.members_pid, from}}
    )

    {:noreply, state}
  end

  def handle_call(:members, _from, state) do
    {:reply, {:ok, state.members}, state}
  end

  def handle_call({:request, name, message, pid}, _from, state) do
    case :ets.lookup(state.ets_table, name) do
      [{^name, data}] ->
        GenServer.cast(
          state.processes_pid,
          {:operation, {:remove, [name]}}
        )
        :ets.delete(state.ets_table, name)
        {:reply, {:ok, :data, data}, state}
      _ ->
        requests = Map.put(state.requests, name, {pid, message})
        {:reply, {:ok, :requested}, %State{state | requests: requests}}
    end
  end

  def handle_call({:unrequest, name}, _from, state) do
    requests = Map.delete(state.requests, name)
    {:reply, :ok, %State{state | requests: requests}}
  end

  def handle_cast({:store, name, data}, state) do
    case Map.get(state.requests, name) do
      nil ->
        GenServer.cast(
          state.processes_pid,
          {:operation, {:add, [name, data]}}
        )
        :ets.insert(state.ets_table, {name, data})
      {pid, message} ->
        send(pid, {message, data})
    end
    {:noreply, state}
  end

  def handle_cast(
        {:request_to_join_hordes, {_other_node_id, other_members_pid, reply_to}},
        state
      ) do
    Kernel.send(state.members_pid, {:add_neighbours, [other_members_pid]})
    GenServer.reply(reply_to, true)
    {:noreply, state}
  end

  def handle_info({:processes_updated, reply_to}, state) do
    processes = DeltaCrdt.CausalCrdt.read(state.processes_pid, 30_000)

    :ets.insert(state.ets_table, Map.to_list(processes))

    all_keys = :ets.match(state.ets_table, {:"$1", :_}) |> MapSet.new(fn [x] -> x end)
    new_keys = Map.keys(processes) |> MapSet.new()
    to_delete_keys = MapSet.difference(all_keys, new_keys)

    to_delete_keys |> Enum.each(fn key -> :ets.delete(state.ets_table, key) end)

    GenServer.reply(reply_to, :ok)

    requests =
      state.requests
      |> Enum.filter(fn {name, {pid, message}} ->
        case Map.get(processes, name) do
          nil ->
            true
          data ->
            send(pid, {message, data})
            GenServer.cast(
              state.processes_pid,
              {:operation, {:remove, [name]}}
            )
            :ets.delete(state.ets_table, name)
            false
        end
      end)
      |> Enum.into(%{})
    state = %State{state | requests: requests}

    {:noreply, state}
  end

  def handle_info({:members_updated, reply_to}, state) do
    members = DeltaCrdt.CausalCrdt.read(state.members_pid, 30_000)

    member_pids =
      MapSet.new(members, fn {_key, {members_pid, _processes_pid}} -> members_pid end)
      |> MapSet.delete(nil)

    state_member_pids =
      MapSet.new(state.members, fn {_key, {members_pid, _processes_pid}} -> members_pid end)
      |> MapSet.delete(nil)

    # if there are any new pids in `member_pids`
    if MapSet.difference(member_pids, state_member_pids) |> Enum.any?() do
      processes_pids =
        MapSet.new(members, fn {_node_id, {_mpid, pid}} -> pid end) |> MapSet.delete(nil)

      Kernel.send(state.members_pid, {:add_neighbours, member_pids})
      Kernel.send(state.processes_pid, {:add_neighbours, processes_pids})
    end

    GenServer.reply(reply_to, :ok)

    {:noreply, %{state | members: members}}
  end

  def handle_info({:EXIT, _pid, reason}, state) do
    {:stop, reason, state}
  end

  def handle_info(whatevah, state) do
    Logger.warn("**** Received unexpected message: #{inspect(whatevah)}")
    {:noreply, state}
  end

  def terminate(reason, state) do
    Logger.info("**** Terminating handoff due to #{inspect(reason)}")
    GenServer.cast(
      state.members_pid,
      {:operation, {:remove, [state.node_id]}}
    )

    GenServer.stop(state.members_pid, reason, 2000)
    GenServer.stop(state.processes_pid, reason, 2000)
  end

  defp generate_node_id(bytes \\ 16) do
    :base64.encode(:crypto.strong_rand_bytes(bytes))
  end
end
