defmodule Tanx.Util.SystemTime do

  @moduledoc """
    This module provides an interface for getting system time. You can get either
    the actual system time or a "fake" system time that can be used for tests.
  """


  #### Public API


  @doc """
    Returns the system time given a time configuration.
    If nil is passed as the time configuration, the actual system time in milliseconds is returned.
    Otherwise, the last time set in the configuration is returned.
  """
  def get(nil) do
    :erlang.system_time(:milli_seconds) / 1000
  end
  def get(config) do
    Agent.get(config, &(&1))
  end


  @doc """
    Creates a new configuration object
  """
  def new_config(time \\ 0.0) do
    {:ok, pid} = Agent.start_link(fn() -> time end)
    pid
  end


  @doc """
    Sets the time that will be returned by the given configuration object
  """
  def set(config, time) do
    Agent.update(config, fn _ -> time end)
  end


  @doc """
    Deletes a configuration object
  """
  def delete_config(config) do
    :ok = Agent.stop(config)
  end

end
