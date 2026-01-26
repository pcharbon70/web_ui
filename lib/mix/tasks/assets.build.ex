defmodule Mix.Tasks.Assets.Build do
  @moduledoc """
  Build all frontend assets (Elm, CSS, JS).

  This task compiles:
  - Elm files to JavaScript
  - Tailwind CSS
  - JavaScript bundles

  ## Examples

      mix assets.build
      mix assets.build --force

  """

  use Mix.Task

  @shortdoc "Build all frontend assets"

  @impl true
  def run(args) do
    Mix.Task.run("compile.elm", args)
    run_tailwind()
    run_esbuild()
  end

  defp run_tailwind do
    config = Application.get_env(:web_ui, :tailwind, [])
    input = Keyword.get(config, :input, "assets/css/app.css")
    output = Keyword.get(config, :output, "priv/static/web_ui/assets/app.css")
    config_file = Keyword.get(config, :config, "assets/tailwind.config.js")
    minify = Keyword.get(config, :minify, Mix.env() == :prod)

    args = [
      "--input=#{input}",
      "--output=#{output}",
      "--config=#{config_file}"
    ]

    args =
      if minify do
        args ++ ["--minify"]
      else
        args
      end

    Mix.shell().info([
      :cyan,
      "Building Tailwind CSS...",
      :reset
    ])

    case System.cmd("tailwindcss", args, cd: File.cwd!(), stderr_to_stdout: true) do
      {_, 0} ->
        Mix.shell().info([
          :green,
          "✓ Tailwind CSS built",
          :reset
        ])

      {error, _} ->
        Mix.shell().error([
          :red,
          "Error building Tailwind CSS:",
          ?\n,
          error
        ])
    end
  end

  defp run_esbuild do
    config = Application.get_env(:web_ui, :esbuild, [])
    entry = Keyword.get(config, :entry, "assets/js/web_ui_interop.js")
    output = Keyword.get(config, :output, "priv/static/web_ui/assets/interop.js")
    minify = Keyword.get(config, :minify, Mix.env() == :prod)

    args = [
      entry,
      "--bundle",
      "--outfile=" <> output
    ]

    args =
      if minify do
        args ++ ["--minify"]
      else
        args
      end

    Mix.shell().info([
      :cyan,
      "Bundling JavaScript...",
      :reset
    ])

    case System.cmd("esbuild", args, cd: File.cwd!(), stderr_to_stdout: true) do
      {_, 0} ->
        Mix.shell().info([
          :green,
          "✓ JavaScript bundled",
          :reset
        ])

      {error, _} ->
        Mix.shell().error([
          :red,
          "Error bundling JavaScript:",
          ?\n,
          error
        ])
    end
  end
end
