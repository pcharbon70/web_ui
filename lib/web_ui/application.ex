defmodule WebUi.Application do
  @moduledoc """
  The WebUI Application.

  This is the root OTP application for WebUI.

  ## Starting the Application

  WebUI is designed to work as both a library and a standalone application.

  ### As a Library (default)

  When used as a dependency in another application, WebUI will not
  start its own supervision tree unless explicitly configured.

  ### As a Standalone Application

  To start WebUI as a standalone application, configure it in your
  `config/config.exs`:

      config :web_ui, :start,
        children: [
          {WebUi.Endpoint, []}
        ]

  ## Supervision Tree

  The application supervision tree includes:

  * `WebUi.Endpoint` - Phoenix Endpoint for serving web requests
  * `WebUi.Registry` - Registry for name-based process registration
  * `WebUi.DynamicSupervisor` - For dynamically spawned child processes

  ## Configuration

  See `config/config.exs` for available configuration options.
  """

  use Application
  require Logger

  @doc """
  Starts the WebUI application.

  This function is called by OTP when the application starts.
  """
  @impl true
  def start(_type, _args) do
    # Get children from config
    children = children_to_start()

    # Always start the minimal supervision tree with Registry and DynamicSupervisor
    # These are needed for the library to function
    children = ensure_required_children(children)

    Logger.info("WebUI starting supervision tree...")
    start_supervision(children)
  end

  @doc """
  Returns the list of children to start based on configuration.
  """
  def children_to_start do
    case Application.get_env(:web_ui, :start) do
      nil ->
        # Library mode - no children unless explicitly configured via :children
        Application.get_env(:web_ui, :children, [])

      config when is_list(config) ->
        # Check if it's a keyword list with :children key
        if Keyword.keyword?(config) and Keyword.has_key?(config, :children) do
          Keyword.get(config, :children, [])
        else
          # It's a list of child specs
          config
        end

      _ ->
        []
    end
  end

  @doc """
  Returns the default supervision tree children.

  This can be used as a reference for configuring your own children.
  """
  def default_children do
    [
      # Registry for name-based process registration
      {Registry, keys: :unique, name: WebUi.Registry},

      # Dynamic supervisor for child processes
      {DynamicSupervisor, strategy: :one_for_one, name: WebUi.DynamicSupervisor},

      # Phoenix Endpoint (optional - only if configured)
      {WebUi.Endpoint, []}
    ]
  end

  # Starts the supervision tree with the given children.
  defp start_supervision(children) do
    opts = [
      strategy: :one_for_one,
      name: WebUi.Supervisor,
      # Allow graceful shutdown of all children
      shutdown: :infinity
    ]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.info("WebUI supervision tree started")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start WebUI supervision tree: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Ensures that required children (Registry, DynamicSupervisor) are present
  defp ensure_required_children(children) do
    registry_present? =
      Enum.any?(children, fn
        {Registry, opts} when is_list(opts) -> true
        {Registry, _keys, name} when is_atom(name) -> true
        _ -> false
      end)

    registry_child =
      if registry_present? do
        []
      else
        [{Registry, keys: :unique, name: WebUi.Registry}]
      end

    ds_present? =
      Enum.any?(children, fn
        {DynamicSupervisor, opts} when is_list(opts) -> true
        {DynamicSupervisor, _strategy, name} when is_atom(name) -> true
        _ -> false
      end)

    ds_child =
      if ds_present? do
        []
      else
        [{DynamicSupervisor, strategy: :one_for_one, name: WebUi.DynamicSupervisor}]
      end

    registry_child ++ ds_child ++ children
  end

  @doc """
  Stops the WebUI application.

  This function is called by OTP when the application stops.
  It performs graceful shutdown of all children.
  """
  @impl true
  def stop(_state) do
    Logger.info("WebUI stopping...")
    :ok
  end

  @doc """
  Returns the configuration for graceful shutdown.

  ## Configuration

  Set the shutdown timeout in your config:

      config :web_ui, :shutdown_timeout, 30_000

  Defaults to 30 seconds.
  """
  def shutdown_timeout do
    Application.get_env(:web_ui, :shutdown_timeout, 30_000)
  end
end
