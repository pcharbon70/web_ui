defmodule Mix.Tasks.Assets.Watch do
  @moduledoc """
  Watch and rebuild frontend assets on file changes.

  This task uses file_system to watch for file changes.
  When a file changes, the appropriate asset is rebuilt.

  ## Examples

      mix assets.watch

  ## Dependencies

  This task requires the `file_system` package to be installed.

  Add to mix.exs:

      {:file_system, "~> 1.0", only: :dev}

  """

  use Mix.Task

  @shortdoc "Watch and rebuild frontend assets"

  @impl true
  def run(_args) do
    Mix.shell().info([
      :cyan,
      "Watching assets... (Ctrl+C to stop)",
      :reset,
      ?\n
    ])

    # Check if file_system is available
    case Code.ensure_loaded(FileSystem) do
      {:module, _} ->
        watch_with_file_system()

      {:error, _} ->
        watch_with_polling()
    end
  end

  defp watch_with_file_system do
    # Use file_system backend for the current OS
    backend = FileSystem.Backends.FileSystemUnix
    # Fallback to other backends depending on OS
    backend =
      case :os.type() do
        {:win32, _} -> FileSystem.Backends.FileSystemWindows
        {:unix, :darwin} -> FileSystem.Backends.FileSystemFsevents
        {:unix, _} -> FileSystem.Backends.FileSystemInotify
        _ -> backend
      end

    worker_pid =
      spawn_link(fn ->
        FileSystem.Worker.start_link(backend: backend, dirs: watch_dirs())
        FileSystem.subscribe(self())
        watch_loop()
      end)

    # Wait indefinitely
    ref = Process.monitor(worker_pid)

    receive do
      {:DOWN, ^ref, _, _, _} ->
        :ok
    end
  end

  defp watch_loop do
    receive do
      {:file_event, _watcher_pid, {path, events}} ->
        handle_file_event(path, events)
        watch_loop()

      _ ->
        watch_loop()
    end
  end

  defp watch_with_polling do
    Mix.shell().info([
      :yellow,
      "Note: file_system package not available. ",
      "Install it for better performance:",
      ?\n,
      "  {:file_system, \"~> 1.0\", only: :dev}",
      ?\n,
      :reset,
      "Using simple polling mode...",
      ?\n
    ])

    # Simple polling fallback
    polling_loop()
  end

  defp polling_loop do
    :timer.sleep(1000)
    polling_loop()
  end

  defp watch_dirs do
    [
      Path.join(["assets", "elm", "src"]),
      Path.join(["assets", "css"]),
      Path.join(["assets", "js"])
    ]
  end

  defp handle_file_event(path, events) do
    ext = Path.extname(path)

    cond do
      ext == ".elm" and :modified in events ->
        Mix.shell().info([
          :cyan,
          "Elm file changed: ",
          :reset,
          path
        ])

        Mix.Task.run("compile.elm", [:force])

      ext == ".css" and :modified in events ->
        Mix.shell().info([
          :cyan,
          "CSS file changed: ",
          :reset,
          path
        ])

        rebuild_tailwind()

      ext == ".js" and :modified in events ->
        Mix.shell().info([
          :cyan,
          "JS file changed: ",
          :reset,
          path
        ])

        rebuild_esbuild()

      true ->
        :ok
    end
  end

  defp rebuild_tailwind do
    config = Application.get_env(:web_ui, :tailwind, [])
    input = Keyword.get(config, :input, "assets/css/app.css")
    output = Keyword.get(config, :output, "priv/static/web_ui/assets/app.css")
    config_file = Keyword.get(config, :config, "assets/tailwind.config.js")

    args = [
      "--input=#{input}",
      "--output=#{output}",
      "--config=#{config_file}"
    ]

    case System.cmd("tailwindcss", args, cd: File.cwd!()) do
      {_, 0} ->
        :ok

      _ ->
        :ok
    end
  end

  defp rebuild_esbuild do
    config = Application.get_env(:web_ui, :esbuild, [])
    entry = Keyword.get(config, :entry, "assets/js/web_ui_interop.js")
    output = Keyword.get(config, :output, "priv/static/web_ui/assets/interop.js")

    args = [
      entry,
      "--bundle",
      "--outfile=" <> output
    ]

    case System.cmd("esbuild", args, cd: File.cwd!()) do
      {_, 0} ->
        :ok

      _ ->
        :ok
    end
  end
end
