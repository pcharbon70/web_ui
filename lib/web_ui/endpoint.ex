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
        server: true

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

  ## WebSocket

  WebSocket connections are handled at `/socket`.

  ## Code Reloading

  In development, the endpoint supports code reloading for faster feedback.
  """

  use Phoenix.Endpoint, otp_app: :web_ui

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_web_ui_key",
    signing_salt: "web_ui_signing_salt",
    encryption_salt: "web_ui_encryption_salt"
  ]

  socket "/socket", WebUi.UserSocket,
    websocket: true,
    longpoll: false

  # Serve at "/" the static files from "priv/static" directory.
  plug Plug.Static,
    at: "/",
    from: :web_ui,
    gzip: false

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  # Plug for parsing request body
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  # Plug for session handling
  plug Plug.Session, @session_options

  plug Plug.MethodOverride
  plug Plug.Head
  plug WebUi.Router

  @doc """
  Callback for init/1 to configure the endpoint.
  """
  def init(_key, config) do
    # Allow user applications to extend configuration
    if Code.ensure_loaded?(WebUi.EndpointConfig) do
      case function_exported?(WebUi.EndpointConfig, :init, 1) do
        true ->
          apply(WebUi.EndpointConfig, :init, [config])

        false ->
          config
      end
    else
      config
    end
  end
end

defmodule WebUi.UserSocket do
  @moduledoc """
  User socket for WebSocket connections.

  Handles WebSocket connections for real-time communication.
  """

  use Phoenix.Socket

  ## Channels
  channel "events:*", WebUi.EventChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     WebUi.Endpoint.broadcast("users_socket:#{user_id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(_socket), do: nil
end

defmodule WebUi.EventChannel do
  @moduledoc """
  Channel for CloudEvents communication.

  Handles incoming and outgoing CloudEvents over WebSocket.
  """

  use Phoenix.Channel

  @impl true
  def join("events:lobby", _payload, socket) do
    {:ok, socket}
  end

  @impl true
  def join("events:" <> _private_room_id, _params, socket) do
    # Authorization logic can be added here
    {:ok, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("cloudevent", _payload, socket) do
    # Handle incoming CloudEvent
    {:noreply, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (events:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end
end
