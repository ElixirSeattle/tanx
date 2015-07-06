defmodule Tanx.Core.Game do

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def connect(game_pid, name: name) do
    GenServer.call(game_pid, {:connect, name})
  end

  def view(game_pid) do
    GenServer.call(game_pid, {:view})
  end

  def terminate(game_pid) do
    GenServer.call(game_pid, {:terminate})
  end

  def advance_to_time(game_pid, time) do
    GenServer.call(game_pid, {:update, time})
  end


  # GenServer callbacks

  use GenServer


  defmodule PlayerInfo do
    defstruct pid: nil, name: "", kills: 0, deaths: 0
  end

  defmodule State do
    defstruct radius: 10.0, players: [], objects: [], t: 0
  end


  def init(opts) do
    Process.flag(:trap_exit, true)
    Tanx.Core.Clock.start_link(self, opts[:clock_interval] || 20)
    {:ok, %State{t: opts[:starting_time] || 0}}
  end


  def handle_call({:connect, name}, _from, state = %State{players: players}) do
    {:ok, player_pid} = GenServer.start_link(Tanx.Core.Player, {self})
    player_info = %PlayerInfo{pid: player_pid, name: name}
    {:reply, {:ok, player_pid}, %State{state | players: [player_info | players]}}
  end

  def handle_call({:view}, {from, _}, state = %State{players: players, objects: objects}) do
    game_view = players |> Enum.reduce(%Tanx.Core.View{}, fn
      (%PlayerInfo{pid: pid, name: name, kills: kills, deaths: deaths}, view = %Tanx.Core.View{other_players: other_players}) ->
        player_view = %Tanx.Core.View.Player{name: name, kills: kills, deaths: deaths}
        if pid == from do
          %Tanx.Core.View{view | my_player: player_view}
        else
          %Tanx.Core.View{view | other_players: [player_view | other_players]}
        end
    end)

    arena = if game_view.my_player == nil do
      nil
    else
      objects |> Enum.reduce(%Tanx.Core.View.Arena{}, fn
        ({player, object}, view = %Tanx.Core.View.Arena{objects: objs}) ->
          obj_view = Tanx.Core.Object.view(object)
          if player == from && object.__struct__ == Tanx.Core.Tank do
            %Tanx.Core.View.Arena{view | my_tank: obj_view}
          else
            %Tanx.Core.View.Arena{view | objects: [obj_view | objs]}
          end
        end)
    end

    {:reply, {:ok, %Tanx.Core.View{game_view | arena: arena}}, state}
  end

  def handle_call({:add_tank}, {from, _}, state = %State{objects: objects, t: time}) do
    cur_tank = objects |> Enum.find(_tank_detector(from))
    if cur_tank != nil do
      {:reply, :already_present, state}
    else
      new_tank = Tanx.Core.Tank.init(time, 0.0, 0.0)
      {:reply, :ok, %State{state | objects: [{from, new_tank} | objects]}}
    end
  end

  def handle_call({:destroy_tank}, {from, _}, state = %State{objects: objects}) do
    {my_tank, nobjects} = objects |> Enum.partition(_tank_detector(from))
    if Enum.empty?(my_tank) do
      {:reply, :no_tank, state}
    else
      # TODO: add explosion
      {:reply, :ok, %State{state | objects: nobjects}}
    end
  end

  def handle_call({:control_tank, params}, {from, _}, state = %State{objects: objects}) do
    {my_tank, other_objects} = objects |> Enum.partition(_tank_detector(from))
    if Enum.empty?(my_tank) do
      {:reply, :no_tank, state}
    else
      updated_tank = elem(List.first(my_tank), 1) |> Tanx.Core.Object.control(params)
      {:reply, :ok, %State{state | objects: [{from, updated_tank} | other_objects]}}
    end
  end

  def handle_call({:terminate}, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_call({:update, new_time}, _from, state = %State{objects: objects, t: time}) do
    if new_time > time do
      objects = objects |> Enum.map(fn
        ({player, object}) -> {player, object |> Tanx.Core.Object.update(new_time)}
      end)
    end
    {:reply, :ok, %State{state | objects: objects, t: new_time}}
  end


  def handle_info({:EXIT, pid, _}, state = %State{players: players, objects: objects}) do
    nobjects = objects |> Enum.filter(&(elem(&1, 0) != pid))
    nplayers = players |> Enum.filter(&(&1.pid != pid))
    {:noreply, %State{state | players: nplayers, objects: nobjects}}
  end

  def handle_info(request, state), do: super(request, state)


  # Internal utils

  defp _tank_detector(player_pid) do
    fn (obj) ->
      elem(obj, 0) == player_pid && elem(obj, 1).__struct__ == Tanx.Core.Tank
    end
  end

end
