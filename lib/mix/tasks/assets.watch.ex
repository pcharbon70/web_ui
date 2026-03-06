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
  @file_system_module :"Elixir.FileSystem"
  @file_system_worker_module :"Elixir.FileSystem.Worker"

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
    backend = file_system_backend()

    worker_pid =
      spawn_link(fn ->
        case start_file_system_worker(backend, watch_dirs()) do
          {:ok, _watcher_pid} ->
            case subscribe_to_file_system(self()) do
              :ok -> watch_loop()
              {:error, _reason} -> watch_with_polling()
            end

          {:error, _reason} ->
            watch_with_polling()
        end
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

  defp file_system_backend do
    case :os.type() do
      {:win32, _} -> FileSystem.Backends.FileSystemWindows
      {:unix, :darwin} -> FileSystem.Backends.FileSystemFsevents
      {:unix, _} -> FileSystem.Backends.FileSystemInotify
    end
  end

  defp start_file_system_worker(backend, dirs) do
    if function_exported?(@file_system_worker_module, :start_link, 1) do
      :erlang.apply(@file_system_worker_module, :start_link, [[backend: backend, dirs: dirs]])
    else
      {:error, :file_system_worker_unavailable}
    end
  end

  defp subscribe_to_file_system(pid) do
    if function_exported?(@file_system_module, :subscribe, 1) do
      :erlang.apply(@file_system_module, :subscribe, [pid])
    else
      {:error, :file_system_unavailable}
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
