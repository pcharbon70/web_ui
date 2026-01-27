defmodule Mix.Tasks.Compile.Elm do
  @moduledoc """
  Compile Elm source files.

  This task compiles Elm files in assets/elm/src to JavaScript.
  The output is written to priv/static/web_ui/assets/.

  ## Configuration

  In mix.exs, add to compilers:

      compilers: [:elm] ++ Mix.compilers()

  ## Elm compiler options

  The following options can be set in your project configuration:

    * `:elm_path` - Path to Elm source directory (default: "assets/elm")
    * `:elm_main` - Main Elm module (default: "Main")
    * `:elm_output` - Output path for compiled JS (default: "priv/static/web_ui/assets")
    * `:elm_optimize` - Whether to optimize output (default: true for prod, false for dev)

  """

  use Mix.Task.Compiler

  @recursive true
  @manifest ".compile.elm"

  @doc false
  def run(argv) do
    {opts, _, _} =
      OptionParser.parse(argv,
        switches: [force: :boolean, verbose: :boolean],
        aliases: [f: :force, v: :verbose]
      )

    config = get_elm_config()
    force = Keyword.get(opts, :force, false)
    verbose = Keyword.get(opts, :verbose, false)

    with :ok <- check_elm_installed(),
         :ok <- check_elm_src_exists(config),
         :ok <- check_needs_compilation(config, force, verbose) do
      compile_elm(config, verbose)
    end
  end

  defp get_elm_config do
    config = Application.get_env(:web_ui, :elm, [])
    elm_path = Keyword.get(config, :elm_path, "assets/elm")
    elm_main = Keyword.get(config, :elm_main, "Main")
    elm_output = Keyword.get(config, :elm_output, "priv/static/web_ui/assets")
    elm_optimize = Keyword.get(config, :elm_optimize, Mix.env() == :prod)

    File.mkdir_p!(elm_output)

    [
      path: elm_path,
      main: elm_main,
      output: elm_output,
      optimize: elm_optimize
    ]
  end

  defp check_elm_installed do
    case System.cmd("elm", ["--version"], stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {error, _} ->
        Mix.shell().error([
          :red,
          "Could not find elm compiler. ",
          "Please install Elm from https://elm-lang.org/",
          ?\n,
          :reset,
          error
        ])

        {:error, :elm_not_found}
    end
  end

  defp check_elm_src_exists(config) do
    elm_src = Path.join([config[:path], "src", config[:main] <> ".elm"])

    if File.exists?(elm_src) do
      {:ok, elm_src}
    else
      Mix.shell().info([
        :yellow,
        "Elm main file not found: #{elm_src}",
        ?\n,
        "Skipping Elm compilation.",
        ?\n
      ])

      return_compiler_status(diagnostics: [], status: :noop)
    end
  end

  defp check_needs_compilation(config, force, verbose) do
    manifest_path = Path.join(Mix.Project.manifest_path(), @manifest)
    last_compiled = read_manifest(manifest_path)
    current_mtime = get_mtime(config[:path])

    if force or last_compiled < current_mtime do
      :ok
    else
      if verbose, do: Mix.shell().info("Elm sources unchanged, skipping compilation.")
      return_compiler_status(diagnostics: [], status: :noop)
    end
  end

  defp compile_elm(config, verbose) do
    elm_src = Path.join([config[:path], "src", config[:main] <> ".elm"])
    output_file = Path.join(config[:output], "app.js")

    args = build_elm_args(elm_src, output_file, config[:optimize])

    Mix.shell().info([:cyan, "Compiling Elm: ", :reset, elm_src])

    {output, exit_code} = System.cmd("elm", args, cd: File.cwd!(), stderr_to_stdout: true)

    handle_compile_result(output, exit_code, elm_src, verbose)
  end

  defp build_elm_args(elm_src, output_file, true) do
    ["make", elm_src, "--output=#{output_file}", "--optimize"]
  end

  defp build_elm_args(elm_src, output_file, false) do
    ["make", elm_src, "--output=#{output_file}"]
  end

  defp handle_compile_result(_output, 0, elm_src, verbose) do
    manifest_path = Path.join(Mix.Project.manifest_path(), @manifest)
    write_manifest(manifest_path, System.system_time(:second))

    if verbose do
      Mix.shell().info([:green, "Compiled ", :reset, elm_src])
    end

    return_compiler_status(diagnostics: [], status: :ok)
  end

  defp handle_compile_result(output, _exit_code, _elm_src, _verbose) do
    diagnostics = parse_elm_errors(output)

    Enum.each(diagnostics, fn diag ->
      Mix.shell().error(format_diagnostic(diag))
    end)

    return_compiler_status(diagnostics: diagnostics, status: :error)
  end

  @doc false
  def clean do
    config = Application.get_env(:web_ui, :elm, [])
    elm_output = Keyword.get(config, :elm_output, "priv/static/web_ui/assets")
    manifest_path = Path.join(Mix.Project.manifest_path(), @manifest)

    File.rm(manifest_path)

    js_file = Path.join(elm_output, "app.js")
    if File.exists?(js_file), do: File.rm(js_file)
  end

  # Private helpers

  defp parse_elm_errors(output) do
    output
    |> String.split("\n")
    |> Enum.chunk_every(4)
    |> Enum.flat_map(fn
      [line, _separator, detail | _] ->
        case parse_error_line(line) do
          {:ok, file, line_no, msg} ->
            [
              %{
                file: file,
                line: line_no,
                message: msg <> ": " <> String.trim(detail),
                severity: :error
              }
            ]

          :error ->
            []
        end

      _ ->
        []
    end)
  end

  defp parse_error_line(line) do
    # Elm error format: [-- PATH/FILE.elm LINE:1]
    regex = ~r/--\s+(.+\.elm)\s+(\d+):(\d+)/

    case Regex.run(regex, line) do
      [_, file, line, _col] ->
        {line_no, _} = Integer.parse(line)
        msg = "Error in " <> file

        {:ok, file, line_no, msg}

      _ ->
        :error
    end
  end

  defp format_diagnostic(diag) do
    [
      :red,
      "error: ",
      :reset,
      diag.file,
      ":",
      to_string(diag.line),
      ": ",
      diag.message,
      ?\n
    ]
  end

  defp get_mtime(path) do
    path
    |> Path.join("**/*.elm")
    |> Path.wildcard()
    |> Enum.map(fn file ->
      File.stat!(file).mtime |> DateTime.to_unix()
    end)
    |> Enum.max(fn -> 0 end)
  end

  defp read_manifest(path) do
    case File.read(path) do
      {:ok, contents} ->
        String.to_integer(contents)

      {:error, _} ->
        0
    end
  end

  defp write_manifest(path, timestamp) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, to_string(timestamp))
  end

  defp return_compiler_status(opts) do
    _diagnostics = Keyword.get(opts, :diagnostics, [])
    status = Keyword.get(opts, :status, :ok)

    # Return the status for Mix to handle
    status
  end
end
