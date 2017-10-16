defmodule Tanx.Clock do

  @moduledoc """
  The Clock process implements a clock that sends a tick message to a recipient process
  on an interval schedule with millisecond accuracy.

  It waits for the recipient to acknowledge with a "tock" that it has completed processing
  before sending the next tick, to ensure that a long running periodic task doesn't overlap
  itself. As a result, the interval may be variable. For instance, suppose a clock is running
  with an interval of 20 milliseconds, and most tocks come back after 10 milliseconds, but
  one tock doesn't come back until 30 milliseconds after the tick. It might look like this:
  - **time=0** Tick sent
  - **time=10** Tock received (after 10 milliseconds)
  - **time=20** Tick sent (20 millisecond interval)
  - **time=30** Waiting for Tock... nothing happens...
  - **time=40** 20 milliseconds have elapsed, but no tock received yet, so tick not sent.
  - **time=50** Tock finally received (after 30 milliseconds this time). Tick sent immediately.
  - **time=60** Tock received (after 10 milliseconds)
  - **time=70** Tick sent (20 millisecond interval, but now offset)

  If you set the interval to nil, automatic ticks are disabled. You can then send manual
  ticks using the manual_tick function. This is useful for unit testing.
  """


  #### Public API


  @doc """
  Start a new clock with a recipient GenServer PID and an interval in milliseconds.

  Provide a nil interval to disable automatic ticking.
  """
  def start_link(recipient_pid, interval_millis, time_config) do
    {:ok, pid} = GenServer.start_link(__MODULE__,
        {recipient_pid, interval_millis, time_config})
    pid
  end


  @doc """
  Send a manual tick with the given time value, and waits for the responding tock to arrive.
  Returns one of the following:
  - **:ok** The tick was sent and the tock was received.
  - **{:error, :currently_ticking}** The tick was not sent because the last tick has not yet been
    acknowledged with a tock.
  - **{:error, :backwards_time}** The tick was not sent because the given time value is less than the
    last time value.
  - **{:error, :automatically_ticking}** The manual tick was not sent because this clock is
    automatically ticking.
  """
  def manual_tick(clock, time_millis) do
    case GenServer.call(clock, {:manual_tick, time_millis}) do
      :ok ->
        receive do
          {:clock_tock, ^clock} -> :ok
        end
      err -> err
    end
  end


  @doc """
  Returns the current tick time for this clock.
  """
  def last_time(clock) do
    GenServer.call(clock, :last_time)
  end


  @doc """
    Sends a tock message back to this clock indicating that handling of the last tick is complete.
  """
  def send_tock(clock) do
    GenServer.cast(clock, :clock_tock)
  end


  #### GenServer callbacks

  use GenServer


  defmodule State do
    defstruct recipient_pid: nil,
              time_config: nil,
              interval: nil,
              last: 0,
              is_waiting: false
  end


  def init({recipient_pid, interval, time_config}) do
    initial_time = if interval == nil, do: 0, else: Tanx.SystemTime.get(time_config)
    state = %State{
      recipient_pid: recipient_pid,
      time_config: time_config,
      interval: interval,
      last: initial_time
    }
    {:ok, state, _timeout(state)}
  end


  def handle_call(:last_time, _from, state) do
    {:reply, state.last, state}
  end


  def handle_call({:manual_tick, _time}, _from, state = %State{interval: interval}) when interval != nil do
    {:reply, {:error, :automatically_ticking}, state, _timeout(state)}
  end
  def handle_call({:manual_tick, _time}, _from, state = %State{is_waiting: true}) do
    {:reply, {:error, :currently_ticking}, state}
  end
  def handle_call({:manual_tick, time}, _from, state = %State{last: last}) when time < last do
    {:reply, {:error, :backwards_time}, state}
  end
  def handle_call({:manual_tick, time}, {from, _}, state) do
    if state.time_config != nil do
      Tanx.SystemTime.set(state.time_config, time)
    end
    GenServer.cast(state.recipient_pid, {:clock_tick, self(), state.last, time})
    state = %State{state | is_waiting: from, last: time}
    {:reply, :ok, state}
  end


  def handle_cast({:set_interval, new_interval}, state) do
    state = %State{state | interval: new_interval}
    {:noreply, state, _timeout(state)}
  end


  def handle_cast(:clock_tock, state) do
    if is_pid(state.is_waiting) do
      send(state.is_waiting, {:clock_tock, self()})
    end
    state = %State{state | is_waiting: false}
    {:noreply, state, _timeout(state)}
  end


  def handle_info(:timeout, state) do
    cur = Tanx.SystemTime.get(state.time_config)
    GenServer.cast(state.recipient_pid, {:clock_tick, self(), state.last, cur})
    state = %State{state | is_waiting: true, last: cur}
    {:noreply, state}
  end

  def handle_info(request, state), do: super(request, state)


  #### Internal utils

  defp _timeout(state) do
    if state.is_waiting || state.interval == nil do
      :infinity
    else
      max(state.last + state.interval - Tanx.SystemTime.get(state.time_config), 0)
    end
  end

end
