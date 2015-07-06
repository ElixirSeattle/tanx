defmodule Tanx.Core.Clock do

  def start_link(game_pid, interval_millis) do
    spawn_link(fn -> _run_clock(game_pid, interval_millis, 0) end)
  end


  defp _run_clock(game_pid, interval_millis, last_millis) do
    if interval_millis >= 0 do
      cur_millis = _cur_millis()
      timeout = max(last_millis + interval_millis - cur_millis, 0)
      next_millis = cur_millis + timeout
    else
      next_millis = last_millis
      timeout = 5000
    end
    receive do
      {_sender, {:set_interval, new_interval}} ->
        _run_clock(game_pid, new_interval, last_millis)
      after timeout ->
        if interval_millis >= 0 and game_pid != nil do
          GenServer.call(game_pid, {:update, next_millis})
        end
        _run_clock(game_pid, interval_millis, next_millis)
    end
  end

  defp _cur_millis() do
    {gs, s, ms} = :erlang.now()
    gs * 1000000000 + s * 1000 + div(ms, 1000)
  end

end
