defmodule Tanx.Core.Player do

  # Client API

  def new_tank(player_pid) do
    GenServer.call(player_pid, {:new_tank})
  end

  def destroy_tank(player_pid) do
    GenServer.call(player_pid, {:destroy_tank})
  end

  def control_tank(player_pid, params) do
    GenServer.call(player_pid, {:control_tank, params})
  end

  def view(player_pid) do
    GenServer.call(player_pid, {:view})
  end

  def disconnect(player_pid) do
    GenServer.call(player_pid, {:disconnect})
  end


  # GenServer callbacks

  use GenServer


  defmodule State do
    defstruct game_pid: nil
  end


  def init({game_pid}) do
    {:ok, %State{game_pid: game_pid}}
  end


  def handle_call({:new_tank}, _from, state = %State{game_pid: game_pid}) do
    {:reply, GenServer.call(game_pid, {:add_tank}), state}
  end

  def handle_call({:destroy_tank}, _from, state = %State{game_pid: game_pid}) do
    {:reply, GenServer.call(game_pid, {:destroy_tank}), state}
  end

  def handle_call({:control_tank, params}, _from, state = %State{game_pid: game_pid}) do
    {:reply, GenServer.call(game_pid, {:control_tank, params}), state}
  end

  def handle_call({:view}, _from, state = %State{game_pid: game_pid}) do
    {:reply, GenServer.call(game_pid, {:view}), state}
  end

  def handle_call({:disconnect}, _from, state) do
    {:stop, :normal, :ok, state}
  end


end
