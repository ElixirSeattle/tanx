defmodule Tanx.Util.ID do

  def create(prefix, map) when is_map(map), do: create(prefix, [map])

  def create(prefix, maps) when is_list(maps) do
    candidate = prefix <> create()
    if Enum.any?(maps, fn map -> Map.has_key?(map, candidate) end) do
      create(prefix, maps)
    else
      candidate
    end
  end

  def create() do
    (:rand.uniform(0x100000000) - 1)
    |> Integer.to_string(16)
    |> String.downcase
    |> String.pad_leading(8, "0")
  end

end
