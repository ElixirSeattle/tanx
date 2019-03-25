defmodule Tanx.Handoff.Supervisor do
  use Supervisor

  def init(options) do
    root_name = Keyword.get(options, :root_name, "none")

    unless is_atom(root_name) do
      raise ArgumentError,
            "expected :root_name to be given and to be an atom, got: #{inspect(root_name)}"
    end

    children = [
      {DeltaCrdt,
       crdt: DeltaCrdt.AWLWWMap,
       notify: {root_name, :members_updated},
       name: members_crdt_name(root_name),
       sync_interval: 5,
       ship_interval: 5,
       ship_debounce: 1},
      {DeltaCrdt,
       crdt: DeltaCrdt.AWLWWMap,
       notify: {root_name, :handoff_updated},
       name: handoff_crdt_name(root_name),
       sync_interval: 5,
       ship_interval: 50,
       ship_debounce: 100},
      {Tanx.Handoff.Impl,
       name: root_name,
       meta: Keyword.get(options, :meta),
       members: Keyword.get(options, :members),
       init_module: Keyword.get(options, :init_module)}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  defp members_crdt_name(name), do: :"#{name}.MembersCrdt"
  defp handoff_crdt_name(name), do: :"#{name}.HandoffCrdt"
end
