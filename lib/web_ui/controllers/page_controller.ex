defmodule WebUi.PageController do
  @moduledoc """
  Controller for serving the Elm SPA bootstrap HTML.

  This controller handles serving the single-page application, including
  passing server-side flags to Elm, security headers, and error handling.

  ## Features

  * Serves HTML with Elm app mount point
  * Passes WebSocket URL and server flags to Elm
  * Sets cache control headers
  * Supports CSP nonce for inline scripts
  * Provides health check endpoint
  * Error page rendering

  ## Configuration

  Configure in your `config/config.exs`:

      config :web_ui, WebUi.PageController,
        cache_control: "no-cache",
        csp_enabled: true,
        websocket_path: "/socket/websocket",
        page_title: "My App"

  ## Server Flags

  Server flags are passed to Elm via the `window.serverFlags` global:

  ```javascript
  window.serverFlags = {
    now: 1234567890,
    wsUrl: "ws://localhost:4000/socket/websocket",
    userAgent: "Mozilla/5.0...",
    custom: { /* from application config */ }
  }
  ```

  Add custom flags via:

      config :web_ui, :server_flags,
        user_id: fn conn -> get_session(conn, :user_id) end,
        api_key: "your-key"
  """

  use Phoenix.Controller,
    formats: [html: "View", json: "View"]

  require Logger

  @doc """
  Serves the Elm SPA index page.

  Renders the HTML bootstrap with Elm app mount point, CSS, and JavaScript.
  Server-side flags are passed via `window.serverFlags` and WebSocket URL
  via `window.wsUrl`.
  """
  def index(conn, params) do
    flags = get_server_flags(conn, params)
    nonce = get_csp_nonce(conn)

    conn
    |> put_cache_header()
    |> render(:index, %{flags: flags, nonce: nonce})
  end

  @doc """
  Health check endpoint.

  Returns JSON with status and version information.
  Useful for load balancers and monitoring systems.

  ## Response

      %{
        status: "ok",
        version: "0.1.0",
        timestamp: 1234567890
      }
  """
  def health(conn, _params) do
    json(conn, %{
      status: "ok",
      version: version(),
      timestamp: System.system_time(:millisecond)
    })
  end

  @doc """
  Renders an error page.

  Used for displaying error information to users.

  ## Options

  * `:status` - HTTP status code (default: 500)
  * `:title` - Error title (default: "An Error Occurred")
  * `:message` - Error message (default: generic message)

  ## Example

      error(conn, status: 404, title: "Not Found", message: "The page you requested could not be found.")
  """
  def error(conn, opts \\ []) do
    status = Keyword.get(opts, :status, 500)
    title = Keyword.get(opts, :title, "An Error Occurred")
    message = Keyword.get(opts, :message, "Something went wrong. Please try again later.")
    nonce = get_csp_nonce(conn)

    conn
    |> put_status(status)
    |> render(:error, %{title: title, message: message, nonce: nonce})
  end

  @doc """
  Gets the current application version.
  """
  @spec version() :: String.t()
  def version do
    case :application.get_key(:web_ui, :vsn) do
      {:ok, version} -> List.to_string(version)
      _ -> Application.spec(:web_ui, :vsn) || "0.1.0"
    end
  end

  # Private Functions

  defp get_server_flags(conn, params) do
    %{
      now: System.system_time(:millisecond),
      ws_url: websocket_url(conn),
      page: params["page"] || "index",
      user_agent: get_req_header(conn, "user-agent") |> List.first(nil),
      custom: get_custom_flags(conn)
    }
  end

  defp get_custom_flags(conn) do
    case Application.get_env(:web_ui, :server_flags) do
      nil -> %{}
      flags when is_list(flags) -> resolve_flags(flags, conn)
      flags when is_map(flags) -> resolve_flag_map(flags, conn)
      _ -> %{}
    end
  end

  defp resolve_flag_map(flags, conn) when is_map(flags) do
    Enum.reduce(flags, %{}, fn
      {key, value}, acc when is_function(value, 1) ->
        Map.put(acc, key, value.(conn))

      {key, value}, acc ->
        Map.put(acc, key, value)
    end)
  end

  defp resolve_flags(flags, conn) when is_list(flags) do
    Enum.reduce(flags, %{}, fn
      {key, value}, acc when is_function(value, 1) ->
        Map.put(acc, key, value.(conn))

      {key, value}, acc ->
        Map.put(acc, key, value)
    end)
  end

  defp websocket_url(conn) do
    scheme = if conn.scheme == :https, do: "wss", else: "ws"
    host = conn.host
    port = conn.port

    websocket_path = Application.get_env(:web_ui, WebUi.PageController, [])
    |> Keyword.get(:websocket_path, "/socket/websocket")

    "#{scheme}://#{host}:#{port}#{websocket_path}"
  end

  defp put_cache_header(conn) do
    cache_control = Application.get_env(:web_ui, WebUi.PageController, [])
    |> Keyword.get(:cache_control, "no-cache, no-store, must-revalidate")

    put_resp_header(conn, "cache-control", cache_control)
  end

  defp get_csp_nonce(conn) do
    # Get or generate CSP nonce for inline scripts
    # This allows inline scripts while maintaining CSP security
    case get_req_header(conn, "x-csrf-token") do
      [token] when is_binary(token) -> token
      _ -> Base.encode64(:crypto.strong_rand_bytes(16))
    end
  end
end
