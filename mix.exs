defmodule Tanx.Mixfile do
  use Mix.Project

  def project do
    [app: :tanx,
     version: "0.0.1",
     elixir: "~> 1.0",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [mod: {Tanx, []},
     applications: [:phoenix, :phoenix_html, :cowboy, :logger,
                    :phoenix_ecto, :postgrex]]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]

  # Specifies your project dependencies
  #
  # Type `mix help deps` for examples and options
  defp deps do
    [
      {:poison, "~> 1.5"},
      {:phoenix, "~> 1.0.3"},
      {:phoenix_ecto, "~> 1.2"},
      {:postgrex, ">= 0.9.1"},
      {:phoenix_html, "~> 2.2"},
      {:phoenix_live_reload, "~> 1.0.1", only: :dev},
      {:cowboy, "~> 1.0.3"}
    ]
  end
end


defmodule Tanx.MixUtil do

  def get_project() do
    {result, 0} = System.cmd("gcloud", ["config", "list", "project"])
    ~r{project\s=\s(\S+)} |> Regex.run(result) |> Enum.at(1)
  end

  def build_yaml(source) do
    EEx.eval_file("kube/#{source}", [project: get_project()])
  end

  def run(cmd) do
    cmd |> String.to_char_list |> :os.cmd |> IO.puts
  end

  def run_stream(cmd) do
    [bin | args] = String.split(cmd)
    {_, 0} = System.cmd(bin, args, into: IO.stream(:stdio, :line))
  end

  def echo_and_run(cmd) do
    IO.puts cmd
    run cmd
  end

  def echo_and_run_stream(cmd) do
    IO.puts cmd
    run_stream cmd
  end

end


defmodule Mix.Tasks do

  defmodule Kube.Build do
    use Mix.Task

    def run(_args) do
      project = Tanx.MixUtil.get_project
      Tanx.MixUtil.echo_and_run_stream "docker build -t gcr.io/#{project}/tanx ."
      Tanx.MixUtil.echo_and_run_stream "gcloud docker push gcr.io/#{project}/tanx"
    end
  end

  defmodule Kube.Phoenix.Start do
    use Mix.Task

    def run(_args) do
      yaml = Tanx.MixUtil.build_yaml("rc-phoenix.yaml")
      Tanx.MixUtil.run "echo '#{yaml}' | kubectl create -f -"
    end
  end

  defmodule Kube.Phoenix.Stop do
    use Mix.Task

    def run(_args) do
      Tanx.MixUtil.echo_and_run "kubectl stop rc phoenix"
    end
  end

  defmodule Kube.Phoenix.Update do
    use Mix.Task

    def run(_args) do
      yaml = Tanx.MixUtil.build_yaml("rc-phoenix.yaml")
      Tanx.MixUtil.echo_and_run "kubectl stop rc phoenix"
      Tanx.MixUtil.run "echo '#{yaml}' | kubectl create -f -"
    end
  end

  defmodule Kube.Balancer.Start do
    use Mix.Task

    def run(_args) do
      yaml = Tanx.MixUtil.build_yaml("service-phoenix.yaml")
      Tanx.MixUtil.run "echo '#{yaml}' | kubectl create -f -"
    end
  end

  defmodule Kube.Balancer.Ip do
    use Mix.Task

    def run(_args) do
      ipaddr = get_ipaddr()
      IO.puts("IP ADDRESS: #{ipaddr}")
    end

    defp get_ipaddr() do
      {result, 0} = System.cmd("kubectl", ["get", "services", "phoenix"])
      match = ~r{\n\s+(\d+\.\d+\.\d+\.\d+)} |> Regex.run(result)
      case match do
        nil ->
          IO.puts("ip address not yet available...")
          :timer.sleep(5000)
          get_ipaddr()
        [_, ipaddr] -> ipaddr
      end
    end
  end

  defmodule Kube.Balancer.Stop do
    use Mix.Task

    def run(_args) do
      Tanx.MixUtil.echo_and_run "kubectl delete services phoenix"
    end
  end

end
