defmodule Mix.Tasks.Assets.Clean do
  @moduledoc """
  Clean built frontend assets.

  ## Examples

      mix assets.clean

  """

  use Mix.Task

  @shortdoc "Clean built frontend assets"

  @impl true
  def run(_args) do
    Mix.Task.run("compile.elm", ["--force"])

    config = Application.get_env(:web_ui, :assets, %{})
    output_dir = Keyword.get(config, :output_dir, "priv/static/web_ui/assets")

    if File.exists?(output_dir) do
      File.rm_rf!(output_dir)

      Mix.shell().info([
        :green,
        "✓ Assets cleaned",
        :reset
      ])
    else
      Mix.shell().info([
        :yellow,
        "No assets to clean",
        :reset
      ])
    end
  end
end
