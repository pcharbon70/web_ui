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
    output = Keyword.get(config, :output, "priv/static/assets/app.css")
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

    case find_tool("tailwindcss") do
      nil ->
        Mix.shell().error([
          :red,
          "Could not find tailwindcss binary. Install dependencies with 'npm install' in assets.",
          :reset
        ])

      tailwind_cmd ->
        case System.cmd(tailwind_cmd, args, cd: File.cwd!(), stderr_to_stdout: true) do
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
  end

  defp run_esbuild do
    config = Application.get_env(:web_ui, :esbuild, [])
    entry = Keyword.get(config, :entry, "assets/js/web_ui_interop.js")
    output = Keyword.get(config, :output, "priv/static/assets/interop.js")
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

    case find_tool("esbuild") do
      nil ->
        Mix.shell().error([
          :red,
          "Could not find esbuild binary. Install dependencies with 'npm install' in assets.",
          :reset
        ])

      esbuild_cmd ->
        case System.cmd(esbuild_cmd, args, cd: File.cwd!(), stderr_to_stdout: true) do
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

  defp find_tool(name) do
    System.find_executable(name) || local_tool_path(name)
  end

  defp local_tool_path(name) do
    candidate = Path.join([File.cwd!(), "assets", "node_modules", ".bin", name])

    if File.exists?(candidate) do
      candidate
    else
      nil
    end
  end
end
