defmodule Tanx.Util.ID do

  def set_strategy(strategy) do
    :erlang.put(:id_strategy, strategy)
    strategy
  end

  def create(prefix, map) do
    create(prefix, map, :erlang.get(:id_strategy))
  end

  def create(prefix, map, :sequential) do
    Stream.iterate(0, &(&1 + 1))
    |> Enum.find_value(fn val ->
      candidate = encode_value(val, prefix)
      if Map.has_key?(map, candidate) do
        nil
      else
        candidate
      end
    end)
  end

  def create(prefix, map, strategy) do
    candidate = encode_value(:rand.uniform(0x100000000) - 1, prefix)
    if Map.has_key?(map, candidate) do
      create(prefix, map, strategy)
    else
      candidate
    end
  end

  defp encode_value(value, prefix) do
    id =
      value
      |> Integer.to_string(16)
      |> String.downcase
      |> String.pad_leading(8, "0")
    prefix <> id
  end

end
