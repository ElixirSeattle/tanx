defmodule Tanx.Util.ID do
  def set_strategy(strategy) do
    :erlang.put(:id_strategy, strategy)
    strategy
  end

  def create(prefix, map, size \\ 3) do
    create(prefix, map, size, :erlang.get(:id_strategy))
  end

  def create(prefix, map, _size, :sequential) do
    Stream.iterate(1, &(&1 + 1))
    |> Enum.find_value(fn val ->
      candidate = prefix <> Integer.to_string(val)

      if Map.has_key?(map, candidate) do
        nil
      else
        candidate
      end
    end)
  end

  def create(prefix, map, size, strategy) do
    candidate = random_value(prefix, size)

    if Map.has_key?(map, candidate) do
      create(prefix, map, strategy)
    else
      candidate
    end
  end

  defp random_value(prefix, size) do
    id =
      size
      |> random_max
      |> :rand.uniform()
      |> Integer.to_string(36)
      |> String.downcase()
      |> String.pad_leading(size, "0")

    prefix <> id
  end

  defp random_max(3), do: 46655
  defp random_max(8), do: 2_821_109_907_455
end
