defmodule WebUi.EventChannel do
  @moduledoc """
  Phoenix Channel for CloudEvents communication over WebSocket.

  This channel handles bidirectional CloudEvents communication with proper
  authorization, validation, broadcasting, and heartbeat support.

  ## Topics

  * `"events:lobby"` - Public lobby for all clients
  * `"events:<room_id>"` - Private room for specific events
  * `"events:user:<user_id>"` - User-specific channel

  ## Client Messages

  Clients can send the following events:

  * `"cloudevent"` - Send a CloudEvent to the server
  * `"ping"` - Ping the server (responds with `"pong"`)
  * `"subscribe"` - Subscribe to specific event types
  * `"unsubscribe"` - Unsubscribe from event types

  ## Server Messages

  Server broadcasts these events:

  * `"cloudevent"` - A CloudEvent from another client or server
  * `"pong"` - Response to a ping message
  * `"heartbeat"` - Periodic heartbeat to keep connection alive
  * `"error"` - Error response for invalid events

  ## Authorization

  Join authorization can be configured via `:authorize_join` in the
  application configuration. The callback receives the topic, payload,
  and socket, and should return `{:ok, socket}` or `{:error, reason}`.

      config :web_ui, WebUi.EventChannel,
        authorize_join: {MyApp.Auth, :authorize_channel_join}

  ## Examples

  Client-side JavaScript:

      const socket = new Socket("/socket", {params: {token: window.userToken}})
      socket.connect()

      const channel = socket.channel("events:lobby", {})
      channel.join()
        .receive("ok", resp => { console.log("Joined successfully", resp) })
        .receive("error", resp => { console.log("Unable to join", resp) })

      // Receive CloudEvents from server
      channel.on("cloudevent", event => {
        console.log("Received CloudEvent:", event)
      })

      // Receive heartbeat messages
      channel.on("heartbeat", msg => {
        console.log("Heartbeat:", msg)
      })

      // Send a CloudEvent
      channel.push("cloudevent", {
        specversion: "1.0",
        id: "123",
        source: "/my/source",
        type: "com.example.event",
        data: { message: "Hello" }
      })

      // Send ping
      channel.push("ping", {})
        .receive("ok", resp => console.log("Pong:", resp))

  ## Configuration

  Configure the channel in your `config/config.exs`:

      config :web_ui, WebUi.EventChannel,
        heartbeat_interval: 30_000,  # 30 seconds
        authorize_join: nil,  # Optional authorization callback
        presence: true,
        event_routing: true

  """

  use Phoenix.Channel
  require Logger

  @type topic :: String.t()
  @type event :: map()

  # Configuration

  @heartbeat_interval Keyword.get(
                       Application.compile_env(:web_ui, WebUi.EventChannel, []),
                       :heartbeat_interval,
                       30_000
                     )

  @doc """
  Authorizes and handles client joining the channel.

  ## Authorization

  If `:authorize_join` is configured, it will be called with
  `{topic, payload, socket}` and should return `{:ok, socket}`
  or `{:error, reason}`.

  ## Examples

      iex> # For "events:lobby" - public access
      iex> WebUi.EventChannel.join("events:lobby", %{}, socket)
      {:ok, socket}

      iex> # For "events:room123" - private room
      iex> WebUi.EventChannel.join("events:room123", %{}, socket)
      {:ok, socket}

  """
  @impl true
  def join("events:lobby", payload, socket) do
    Logger.debug("Client joining events:lobby")
    authorize_join("events:lobby", payload, socket)
  end

  @impl true
  def join("events:" <> room_id, params, socket) do
    Logger.debug("Client joining events:#{room_id}")

    socket =
      socket
      |> assign(:room_id, room_id)
      |> assign(:joined_at, System.system_time(:millisecond))
      |> assign(:last_activity, System.system_time(:millisecond))
      |> assign(:event_subscriptions, [])
      |> assign(:error_count, 0)

    authorize_join("events:#{room_id}", params, socket)
  end

  @impl true
  def join(topic, _payload, _socket) do
    Logger.warning("Invalid join attempt on topic: #{topic}")
    {:error, %{reason: "invalid_topic"}}
  end

  @doc """
  Handles incoming messages from clients.

  Supported message types:
  - `"cloudevent"` - CloudEvents for validation and broadcasting
  - `"ping"` - Ping messages for connection health
  - `"subscribe"` - Subscribe to specific event types
  - `"unsubscribe"` - Unsubscribe from event types

  """
  @impl true
  def handle_in("cloudevent", payload, socket) do
    Logger.debug("Received cloudevent payload",
      type: get_in(payload, ["type"]),
      room_id: socket.assigns[:room_id]
    )

    socket = update_last_activity(socket)

    case validate_and_decode_cloudevent(payload) do
      {:ok, event} ->
        maybe_route_to_subscribers(event, socket)

        broadcast_from(socket, "cloudevent", payload)
        {:noreply, socket}

      {:error, reason} ->
        socket = track_error(socket)
        handle_cloudevent_error(payload, reason, socket)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_in("ping", _payload, socket) do
    socket = update_last_activity(socket)

    pong_response = %{
      type: "pong",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      server_time: System.system_time(:millisecond)
    }

    {:reply, {:ok, pong_response}, socket}
  end

  @impl true
  def handle_in("subscribe", %{"event_types" => types}, socket) when is_list(types) do
    Logger.debug("Client subscribing to event types",
      types: inspect(types),
      room_id: socket.assigns[:room_id]
    )

    current_subs = socket.assigns[:event_subscriptions] || []
    new_subs = Enum.uniq(current_subs ++ types)

    socket =
      socket
      |> assign(:event_subscriptions, new_subs)
      |> update_last_activity()

    {:reply, {:ok, %{subscribed: types}}, socket}
  end

  @impl true
  def handle_in("subscribe", _payload, socket) do
    {:reply, {:error, %{reason: "invalid_subscription_request"}}, socket}
  end

  @impl true
  def handle_in("unsubscribe", %{"event_types" => types}, socket) when is_list(types) do
    Logger.debug("Client unsubscribing from event types",
      types: inspect(types),
      room_id: socket.assigns[:room_id]
    )

    current_subs = socket.assigns[:event_subscriptions] || []
    new_subs = current_subs -- types

    socket =
      socket
      |> assign(:event_subscriptions, new_subs)
      |> update_last_activity()

    {:reply, {:ok, %{unsubscribed: types}}, socket}
  end

  @impl true
  def handle_in("unsubscribe", _payload, socket) do
    {:reply, {:error, %{reason: "invalid_unsubscription_request"}}, socket}
  end

  @impl true
  def handle_in(msg_type, payload, socket) do
    Logger.warning("Received unknown message type",
      type: msg_type,
      payload: inspect(payload)
    )

    {:noreply, socket}
  end

  @doc """
  Handles client disconnect with proper cleanup.

  Logs disconnect reason and performs cleanup of any resources
  associated with the connection.

  """
  @impl true
  def terminate(reason, socket) do
    room_id = socket.assigns[:room_id]
    subscriptions = socket.assigns[:event_subscriptions] || []

    Logger.debug("Client disconnecting",
      room_id: room_id,
      reason: inspect(reason),
      subscriptions: length(subscriptions)
    )

    :ok
  end

  # Public API Functions

  @doc """
  Broadcasts a CloudEvent to all subscribers in a room.

  ## Parameters

  * `room_id` - The room identifier
  * `event` - The CloudEvent to broadcast (map or WebUi.CloudEvent struct)

  ## Examples

      WebUi.EventChannel.broadcast_cloudevent("lobby", %{
        specversion: "1.0",
        id: "123",
        source: "/server",
        type: "com.example.update",
        data: %{status: "completed"}
      })

  """
  @spec broadcast_cloudevent(String.t(), map() | WebUi.CloudEvent.t()) :: :ok | {:error, term()}
  def broadcast_cloudevent(room_id, %WebUi.CloudEvent{} = event) do
    event_map = WebUi.CloudEvent.to_json_map(event)
    broadcast_cloudevent(room_id, event_map)
  end

  def broadcast_cloudevent(room_id, event_map) when is_map(event_map) do
    topic = "events:#{room_id}"

    WebUi.Endpoint.broadcast(topic, "cloudevent", event_map)
  end

  @doc """
  Broadcasts a CloudEvent from a specific socket (excluding sender).

  Similar to `broadcast_cloudevent/2` but excludes the sender from
  receiving the broadcast.

  Note: This function must be called from within a Channel process.

  """
  @spec broadcast_cloudevent_from(Phoenix.Socket.t(), String.t(), map()) :: :ok
  def broadcast_cloudevent_from(socket, _room_id, event_map) when is_map(event_map) do
    Phoenix.Channel.broadcast_from(socket, "cloudevent", event_map)
  end

  @doc """
  Sends a heartbeat message to all subscribers in a room.

  ## Parameters

  * `room_id` - The room identifier

  Heartbeat messages help keep connections alive and detect
  disconnected clients.

  ## Examples

      WebUi.EventChannel.send_heartbeat("lobby")

  """
  @spec send_heartbeat(String.t()) :: :ok
  def send_heartbeat(room_id) do
    topic = "events:#{room_id}"

    heartbeat_msg = %{
      type: "heartbeat",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      server_time: System.system_time(:millisecond)
    }

    WebUi.Endpoint.broadcast(topic, "heartbeat", heartbeat_msg)
  end

  @doc """
  Returns the configured heartbeat interval in milliseconds.

  ## Examples

      iex> WebUi.EventChannel.heartbeat_interval()
      30000

  """
  @spec heartbeat_interval() :: pos_integer()
  def heartbeat_interval, do: @heartbeat_interval

  # Private Helper Functions

  defp authorize_join(topic, payload, socket) do
    case get_authorize_callback() do
      {mod, fun} ->
        apply(mod, fun, [topic, payload, socket])

      nil ->
        {:ok, socket}
    end
  end

  defp get_authorize_callback do
    case Application.get_env(:web_ui, WebUi.EventChannel) do
      nil -> nil
      config when is_list(config) -> Keyword.get(config, :authorize_join)
      _ -> nil
    end
  end

  defp validate_and_decode_cloudevent(payload) when is_map(payload) do
    required_fields = ["specversion", "id", "source", "type"]

    with :ok <- validate_required_fields(payload, required_fields),
         :ok <- validate_specversion(payload["specversion"]),
         {:ok, _} <- validate_field(:id, payload["id"]),
         {:ok, _} <- validate_field(:source, payload["source"]),
         {:ok, _} <- validate_field(:type, payload["type"]) do
      {:ok, payload}
    end
  end

  defp validate_and_decode_cloudevent(_payload), do: {:error, :invalid_cloudevent_format}

  defp validate_required_fields(payload, required) do
    present? = Enum.all?(required, &Map.has_key?(payload, &1))

    if present? do
      :ok
    else
      missing = Enum.reject(required, &Map.has_key?(payload, &1))
      {:error, {:missing_fields, missing}}
    end
  end

  defp validate_specversion("1.0"), do: :ok
  defp validate_specversion(_), do: {:error, :invalid_specversion}

  defp validate_field(:id, value) when is_binary(value) and value != "", do: {:ok, value}
  defp validate_field(:id, _), do: {:error, :invalid_id}

  defp validate_field(:source, value) when is_binary(value) and value != "", do: {:ok, value}
  defp validate_field(:source, _), do: {:error, :invalid_source}

  defp validate_field(:type, value) when is_binary(value) and value != "", do: {:ok, value}
  defp validate_field(:type, _), do: {:error, :invalid_type}

  defp handle_cloudevent_error(payload, {:missing_fields, fields}, socket) do
    Logger.warning("CloudEvent missing required fields",
      fields: inspect(fields),
      payload: inspect(payload)
    )

    push(socket, "error", %{
      reason: "missing_required_fields",
      message: "Missing required fields: #{Enum.join(fields, ", ")}"
    })
  end

  defp handle_cloudevent_error(payload, reason, socket) do
    Logger.warning("Invalid CloudEvent received",
      reason: inspect(reason),
      payload: inspect(payload)
    )

    push(socket, "error", %{
      reason: inspect(reason),
      message: "Invalid CloudEvent: #{inspect(reason)}"
    })
  end

  defp maybe_route_to_subscribers(event, socket) do
    subscriptions = socket.assigns[:event_subscriptions] || []
    event_type = get_in(event, ["type"])

    if Enum.any?(subscriptions, fn sub -> matches_type?(event_type, sub) end) do
      Logger.debug("Routing event to subscriber",
        event_type: event_type,
        subscriptions: inspect(subscriptions)
      )
    end

    :ok
  end

  defp matches_type?(event_type, pattern) do
    pattern = Regex.escape(pattern)
    pattern = String.replace(pattern, "\\*", ".*")
    regex = Regex.compile!("^#{pattern}$")

    Regex.match?(regex, event_type)
  end

  defp update_last_activity(socket) do
    assign(socket, :last_activity, System.system_time(:millisecond))
  end

  defp track_error(socket) do
    current_count = socket.assigns[:error_count] || 0
    assign(socket, :error_count, current_count + 1)
  end
end
