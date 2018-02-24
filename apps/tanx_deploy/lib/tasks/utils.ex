defmodule TanxDeploy.Utils do
  def get_default_project do
    {result, _} = System.cmd("gcloud", ["config", "get-value", "project"])
    String.trim(result)
  end

  def make_tag do
    Timex.now()
    |> Timex.format!("%Y-%m-%d-%H%M%S", :strftime)
  end

  def sh(cmd = [binary | args]) do
    cmd |> Enum.join(" ") |> IO.puts()
    {_, 0} = System.cmd(binary, args, into: IO.stream(:stdio, :line), stderr_to_stdout: true)
  end
end
