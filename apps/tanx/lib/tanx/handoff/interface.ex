defmodule Tanx.Handoff do
  @callback init(options :: Keyword.t()) :: {:ok, options :: Keyword.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Tanx.Handoff

      def child_spec(options) do
        options = Keyword.put_new(options, :id, __MODULE__)

        %{
          id: Keyword.get(options, :id, __MODULE__),
          start: {__MODULE__, :start_link, [options]},
          type: :supervisor
        }
      end

      def start_link(options) do
        Tanx.Handoff.start_link(Keyword.put(options, :init_module, __MODULE__))
      end
    end
  end

  def child_spec(options \\ []) do
    options = Keyword.put_new(options, :id, __MODULE__)

    %{
      id: Keyword.get(options, :id, __MODULE__),
      start: {__MODULE__, :start_link, [options]},
      type: :supervisor
    }
  end

  def start_link(options) do
    root_name = Keyword.get(options, :name)

    if is_nil(root_name) do
      raise "must specify :name in options, got: #{inspect(options)}"
    end

    options = Keyword.put(options, :root_name, root_name)

    Supervisor.start_link(Tanx.Handoff.Supervisor, options, name: :"#{root_name}.Supervisor")
  end

  def stop(supervisor, reason \\ :normal, timeout \\ 5000) do
    Supervisor.stop(supervisor, reason, timeout)
  end

  def request(handoff, name, message, pid \\ self()) do
    GenServer.call(handoff, {:request, name, message, pid})
  end

  def unrequest(handoff, name) do
    GenServer.call(handoff, {:unrequest, name})
  end

  def store(handoff, name, data) do
    GenServer.call(handoff, {:store, name, data})
  end
end
