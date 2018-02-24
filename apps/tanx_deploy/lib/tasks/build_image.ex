defmodule Mix.Tasks.BuildImage do
  @moduledoc """
  Mix task that builds the production image
  """

  @shortdoc "Build the production image"

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
          tag: :string
        ]
      )

    project = Keyword.get_lazy(switches, :project, &Utils.get_default_project/0)
    name = Keyword.get(switches, :name, @default_name)
    tag = Keyword.get_lazy(switches, :tag, &Utils.make_tag/0)
    execute(project, name, tag)
  end

  defp execute(project, name, tag) do
    IO.puts("**** Building image...")

    Utils.sh([
      "gcloud",
      "container",
      "builds",
      "submit",
      "--config=cloudbuild.yaml",
      "--substitutions",
      "_APP_NAME=#{name},_TAG=#{tag}",
      "."
    ])

    IO.puts("**** Built image: gcr.io/#{project}/#{name}:#{tag}")
  end
end
