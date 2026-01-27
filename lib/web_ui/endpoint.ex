defmodule WebUi.Endpoint do
  @moduledoc """
  Phoenix Endpoint for WebUI.

  This endpoint serves the Elm SPA and handles WebSocket connections.

  ## Configuration

  Configure the endpoint in your `config/config.exs`:

      config :web_ui, WebUi.Endpoint,
        http: [ip: {127, 0, 0, 1}, port: 4000],
        url: [host: "localhost"],
        secret_key_base: "your_secret_key_base",
        root: ".",
        server: true,
        # WebSocket timeout in milliseconds (default: 60_000)
        websocket_timeout: 60_000

  For development, watchers can be configured to rebuild assets on change:

      config :web_ui, WebUi.Endpoint,
        watchers: [
          elm: {Mix.Tasks.Compile.Elm, :run, [:force, []]},
          tailwind: {fn ->
            # Your watch command here
          end, :restart}
        ]

  ## Static Assets

  Compiled assets are served from `priv/static/web_ui/assets/`.

  In production, assets are cached aggressively using a cache manifest.
  Set `cache_static_manifest` to enable long-term caching.

  ## WebSocket

  WebSocket connections are handled at `/socket`.

  The WebSocket timeout can be configured via the `:websocket_timeout` option.
  Default: 60 seconds for development, 30 seconds for production.

  ## Code Reloading

  In development, the endpoint supports code reloading for faster feedback.

  ## Security

  Security headers are automatically added via `WebUi.Plugs.SecurityHeaders`.
  See that module for configuration options.

  ## SSL/TLS

  For production, configure HTTPS:

      config :web_ui, WebUi.Endpoint,
        https: [
          port: 443,
          cipher_suite: :strong,
          keyfile: System.get_env("SSL_KEY_PATH"),
          certfile: System.get_env("SSL_CERT_PATH")
        ],
        force_ssl: [hsts: true]
  """

  use Phoenix.Endpoint, otp_app: :web_ui

  @session_options [
    store: :cookie,
    key: "_web_ui_key",
    signing_salt: "web_ui_signing_salt",
    encryption_salt: "web_ui_encryption_salt"
  ]

  @endpoint_config Application.compile_env(:web_ui, WebUi.Endpoint, [])
  @default_websocket_timeout (case Mix.env() do
    :dev -> 60_000
    :test -> 5000
    _ -> 30_000
  end)
  @default_gzip Mix.env() == :prod
  @websocket_timeout Keyword.get(@endpoint_config, :websocket_timeout, @default_websocket_timeout)
  @gzip_static Keyword.get(@endpoint_config, :gzip_static, @default_gzip)
  @cache_manifest Keyword.get(@endpoint_config, :cache_static_manifest, "priv/static/cache_manifest.json")

  socket("/socket", WebUi.UserSocket,
    websocket: [timeout: @websocket_timeout, fullsweep_after: 20],
    longpoll: false
  )

  plug(Plug.Static,
    at: "/",
    from: :web_ui,
    gzip: @gzip_static,
    cache_control_for_etags: "public, max-age=31536000",
    cache_control_for_vsn_requests: "public, max-age=31536000",
    only: ~w(assets fonts images favicon.ico robots.txt),
    only_matching: @cache_manifest
  )

  if code_reloading? do
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.Session, @session_options)

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(WebUi.Plugs.SecurityHeaders)

  plug(WebUi.Router)

  @doc """
  Callback for init/1 to configure the endpoint.

  Allows runtime extension via `WebUi.EndpointConfig.init/1` if defined.
  """
  def init(_key, config) do
    if Code.ensure_loaded?(WebUi.EndpointConfig) and
         function_exported?(WebUi.EndpointConfig, :init, 1) do
      WebUi.EndpointConfig.init(config)
    else
      config
    end
  end

  @doc """
  Gets the WebSocket timeout configuration.

  Returns the configured timeout in milliseconds, or environment-specific default.
  """
  @spec websocket_timeout() :: pos_integer()
  def websocket_timeout, do: @websocket_timeout
end

defmodule WebUi.UserSocket do
  @moduledoc """
  User socket for WebSocket connections.

  Handles WebSocket connections for real-time communication.

  ## Security

  The socket performs origin checking in production to prevent CSRF attacks.
  Configure allowed origins via `:allowed_origins` in endpoint configuration.

  ## Configuration

      config :web_ui, WebUi.Endpoint,
        allowed_origins: ["https://example.com", "https://www.example.com"]

  In development, all localhost origins are allowed for convenience.
  """

  use Phoenix.Socket

  @impl true
  def connect(_params, socket, connect_info) do
    origin_check = check_origin(connect_info)

    if origin_check == :ok do
      {:ok, socket}
    else
      :error
    end
  end

  @impl true
  def id(_socket), do: nil

  channel("events:*", WebUi.EventChannel)

  defp check_origin(%{origin: nil}) do
    case Mix.env() do
      :dev -> :ok
      :test -> :ok
      _ -> :error
    end
  end

  defp check_origin(%{origin: origin}) do
    allowed = get_allowed_origins()

    if origin_allowed?(origin, allowed) do
      :ok
    else
      :error
    end
  end

  defp check_origin(_), do: :ok

  defp get_allowed_origins do
    case Application.get_env(:web_ui, WebUi.Endpoint) do
      nil -> default_allowed_origins()
      config when is_list(config) -> Keyword.get(config, :allowed_origins, default_allowed_origins())
      _ -> default_allowed_origins()
    end
  end

  defp default_allowed_origins do
    case Mix.env() do
      :dev ->
        ["http://localhost:*", "http://127.0.0.1:*", "ws://localhost:*", "ws://127.0.0.1:*"]

      :test ->
        ["http://localhost:*"]

      _ ->
        []
    end
  end

  defp origin_allowed?(origin, allowed) when is_list(allowed) do
    origin_uri = URI.parse(origin)

    Enum.any?(allowed, fn pattern ->
      pattern_uri = URI.parse(pattern)

      cond do
        pattern_uri.host == "*" -> true
        pattern_uri.host == origin_uri.host -> ports_match?(origin_uri.port, pattern_uri.port)
        pattern == "*" -> true
        true -> false
      end
    end)
  end

  defp origin_allowed?(_, _), do: false

  defp ports_match?(nil, nil), do: true
  defp ports_match?(_port, "*"), do: true
  defp ports_match?(port, port), do: true
  defp ports_match?(_, _), do: false
end

defmodule WebUi.EventChannel do
  @moduledoc """
  Channel for CloudEvents communication.

  Handles incoming and outgoing CloudEvents over WebSocket.

  ## Topics

  * `"events:lobby"` - Public lobby for all clients
  * `"events:<room_id>"` - Private room for specific events

  ## Client Messages

  Clients can send the following events:

  * `"cloudevent"` - Send a CloudEvent to the server
  * `"ping"` - Ping the server (responds with `"pong"`)

  ## Server Messages

  Server broadcasts these events:

  * `"cloudevent"` - A CloudEvent from another client or server
  * `"pong"` - Response to a ping message

  ## Examples

  Client-side JavaScript:

      socket.channel("events:lobby", {})
      socket.join()
        .receive("ok", resp => { console.log("Joined successfully", resp) })
        .receive("error", resp => { console.log("Unable to join", resp) })

      socket.on("cloudevent", event => {
        console.log("Received CloudEvent:", event)
      })

      socket.push("cloudevent", {
        specversion: "1.0",
        id: "123",
        source: "/my/source",
        type: "com.example.event",
        data: { message: "Hello" }
      })
  """

  use Phoenix.Channel
  require Logger

  @impl true
  def join("events:lobby", _payload, socket) do
    Logger.debug("Client joined events:lobby")
    {:ok, socket}
  end

  @impl true
  def join("events:" <> room_id, _params, socket) do
    Logger.debug("Client joined events:#{room_id}")
    {:ok, socket}
  end

  @impl true
  def handle_in("cloudevent", %{"specversion" => "1.0"} = payload, socket) do
    Logger.debug("Received CloudEvent: #{payload["type"]}")

    broadcast_from(socket, "cloudevent", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("cloudevent", payload, socket) do
    Logger.warning("Received invalid CloudEvent", payload: inspect(payload))
    {:noreply, socket}
  end

  @impl true
  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{type: "pong", timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}}, socket}
  end

  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end
end
