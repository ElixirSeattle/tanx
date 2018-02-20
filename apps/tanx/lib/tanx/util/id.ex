defmodule Tanx.Util.ID do

  def create(map) when is_map(map), do: create([map])

  def create(maps) when is_list(maps) do
    candidate = create()
    if Enum.any?(maps, fn map -> Map.has_key?(map, candidate) end) do
      create(maps)
    else
      candidate
    end
  end

  def create() do
    (:rand.uniform(0x100000000) - 1)
    |> Integer.to_string(16)
    |> String.pad_leading(8, "0")
  end

end
