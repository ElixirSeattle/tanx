defmodule Mix.Tasks.BuildImage do
  @moduledoc """
  Mix task that builds the production image
  """

  @shortdoc "Build the production image"

  use Mix.Task
  alias TanxDeploy.Utils

  @copy_paths [
    "apps", "config", "rel",
    ".dockerignore", "Dockerfile", "mix.exs", "mix.lock"
  ]
  @remove_paths [
    "apps/tanx/test",
    "apps/tanx_web/assets/node_modules",
    "apps/tanx_web/priv/static",
    "apps/tanx_web/test"
  ]
  @default_name "tanx"

  def run(args) do
    {switches, []} =
      OptionParser.parse!(args, strict: [
        project: :string,
        name: :string,
        tag: :string
      ])
    project = Keyword.get_lazy(switches, :project, &Utils.get_default_project/0)
    name = Keyword.get(switches, :name, @default_name)
    tag = Keyword.get_lazy(switches, :tag, &Utils.make_tag/0)
    execute(project, name, tag)
  end

  defp execute(project, name, tag) do
    IO.puts("**** Copying files...")
    copy_files()
    image = "gcr.io/#{project}/#{name}:#{tag}"
    IO.puts("**** Building image...")
    Utils.sh(["gcloud", "container", "builds", "submit", "--tag=#{image}", "_tmp"])
    IO.puts("**** Built image: #{image}")
  end

  defp copy_files do
    File.rm_rf!("_tmp")
    File.mkdir_p!("_tmp")
    Enum.each(@copy_paths, fn path ->
      File.cp_r!(path, "_tmp/#{path}")
    end)
    Enum.each(@remove_paths, fn path ->
      File.rm_rf!("_tmp/#{path}")
    end)
  end
end
