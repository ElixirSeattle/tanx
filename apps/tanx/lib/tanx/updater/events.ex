defmodule Tanx.Updater.TankCreated do
  defstruct(
    id: nil,
    event_data: nil
  )
end

defmodule Tanx.Updater.TankDeleted do
  defstruct(
    id: nil,
    tank: nil,
    event_data: nil
  )
end
