defmodule Tanx.Game.Notifications.Ended do
  defstruct(
    id: nil,
    time: nil,
    data: nil
  )
end

defmodule Tanx.Game.Notifications.Moved do
  defstruct(
    id: nil,
    time: nil,
    from_node: nil,
    to_node: nil
  )
end
