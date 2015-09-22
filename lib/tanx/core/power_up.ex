defmodule Tanx.Core.PowerUp do

  require Logger

  defmodule State do
    defstruct x: 0.0,
              y: 0.0,
              radius: 0.4,
              type: nil
  end

  ############
  #Power_up API

  #Called by "Arena Objects" process.
  def start_link(x, y, type \\ nil) do
    GenServer.start_link(__MODULE__, { x, y, type})
  end

  def get_state(powerup) do
    GenServer.call(powerup, :get_state)
  end

  def collect(pid) do
    GenServer.call(pid, :collect)
  end

  #########################
  #GenServer Implementation

  use GenServer

  def init({x, y, type}) do

    if(type == nil) do
      type = pick_power_up_type()
    end

    {:ok, %Tanx.Core.PowerUp.State{ x: x,
                                    y: y,
                                    type: type}}
  end

  def handle_cast({:update, _last_time, _time, updater}, state) do
    updater |> Tanx.Core.ArenaUpdater.send_update_reply(%Tanx.Core.Updates.PowerUp{powerup: self,
                                                        pos: {state.x, state.y},
                                                        radius: state.radius,
                                                        type: state.type})
    {:noreply, state}
  end

  def handle_call(:collect, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  defp pick_power_up_type() do
    list_of_types = [%Tanx.Core.PowerUpTypes.BouncingMissile{}, %Tanx.Core.PowerUpTypes.HealthKit{}]
    :random.seed(:erlang.now)
    Enum.at(list_of_types, :random.uniform(length(list_of_types)) - 1)
  end
end
