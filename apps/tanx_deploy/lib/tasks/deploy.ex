defmodule Mix.Tasks.Deploy do
  @moduledoc """
  Mix task that does a deployment
  """

  @shortdoc "Deploy tanx"

  use Mix.Task
  alias TanxDeploy.Utils

  @default_name "tanx"

  def run(args) do
    {switches, []} =
      OptionParser.parse!(
        args,
        strict: [
          project: :string,
          name: :string,
          ip: :string
        ]
      )

    project = Keyword.get_lazy(switches, :project, &Utils.get_default_project/0)
    ip = Keyword.get(switches, :ip, nil)
    name = Keyword.get(switches, :name, @default_name)
    execute(project, name, ip)
  end

  defp execute(project, name, ip) do
    tag = Utils.make_tag()
    build_args = ["--project", project, "--name", name, "--tag", tag]
    Mix.Task.run("build_image", build_args)
    image = "gcr.io/#{project}/#{name}:#{tag}"
    do_deploy(name, image, ip)
  end

  defp do_deploy(name, image, nil) do
    IO.puts("**** Updating deployment...")
    Utils.sh(["kubectl", "set", "image", "deployment/#{name}", "#{name}=#{image}"])
  end

  defp do_deploy(name, image, ip) do
    IO.puts("**** Creating deployment...")
    Utils.sh(["kubectl", "run", name, "--image=#{image}", "--port=8080"])
    IO.puts("**** Creating service...")

    expose_cmd = [
      "kubectl",
      "expose",
      "deployment",
      name,
      "--type=LoadBalancer",
      "--port=80",
      "--target-port=8080"
    ]

    expose_cmd =
      if ip != "" && ip != "default" do
        expose_cmd ++ ["--load-balancer-ip=#{ip}"]
      else
        expose_cmd
      end

    Utils.sh(expose_cmd)
  end
end
