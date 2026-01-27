# Phoenix Channel Integration for CloudEvents

**Status:** Design Document
**Phase:** 3 (Phoenix Integration)
**Date:** 2025-01-27

## Overview

This document describes how CloudEvents will be transmitted over Phoenix Channels in Phase 3 of the WebUI implementation. This ensures the frontend (Elm) and backend (Elixir) can communicate using a standardized event format.

## Channel Topic Pattern

```
"events:{scope}"
```

Examples:
- `events:public` - Public events, no authentication required
- `events:user:123` - User-specific events
- `events:admin` - Admin-only events

## Message Format

### Client → Server (Incoming)

```elixir
# Phoenix Channel message format
{
  "topic": "events:public",
  "event": "cloudevent",  # Phoenix event name (fixed)
  "payload": {
    # CloudEvent JSON string
    "event": "{\"specversion\":\"1.0\",\"id\":\"...\",...}"
  },
  "ref": "unique-ref-id",
  "join_ref": "join-ref-id"
}
```

### Server → Client (Outgoing)

```elixir
# Phoenix Channel push format
{
  "topic": "events:public",
  "event": "cloudevent",  # Phoenix event name (fixed)
  "payload": {
    # CloudEvent JSON string
    "event": "{\"specversion\":\"1.0\",\"id\":\"...\",...}"
  },
  "ref": nil  # Server pushes have no ref
}
```

## Channel Handler Example

```elixir
defmodule WebUi.EventChannel do
  use Phoenix.Channel
  require Logger

  @doc """
  Handles client joining the event channel.
  """
  def join("events:" <> _scope, _payload, socket) do
    # Authorization check would go here
    {:ok, socket}
  end

  def join("events:" <> _scope, _payload, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  @doc """
  Handles incoming CloudEvents from clients.
  """
  def handle_in("cloudevent", %{"event" => json_event}, socket) do
    case WebUi.CloudEvent.from_json(json_event) do
      {:ok, event} ->
        # Route to dispatcher
        WebUi.Dispatcher.dispatch(event)
        {:reply, {:ok, %{}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  @doc """
  Handles invalid message formats.
  """
  def handle_in(_event, _payload, socket) do
    {:reply, {:error, %{reason: "unknown_event"}}, socket}
  end

  @doc """
  Intercepts outgoing CloudEvents to ensure proper formatting.
  """
  def handle_out("cloudevent", %{"event" => json_event}, socket) do
    # Validate before sending
    case WebUi.CloudEvent.from_json(json_event) do
      {:ok, _event} ->
        {:noreply, socket}

      {:error, _reason} ->
        # Don't send invalid events
        {:stop, :invalid_event, socket}
    end
  end
end
```

## Client-Side (Elm) Usage Pattern

```elm
-- Subscribe to events
type Msg
    = CloudEventReceived WebUi.CloudEvents.CloudEvent
    | CloudEventSent
    | CloudEventError String

-- Send CloudEvent
sendCloudEvent : String -> Cmd Msg
sendCloudEvent jsonEvent =
    sendCloudEventPort jsonEvent

-- Receive CloudEvent
subscriptions : Model -> Sub Msg
subscriptions model =
    receiveCloudEventPort CloudEventReceived
```

## JavaScript Interop

```javascript
// assets/js/web_ui_interop.js

// Send CloudEvent through Phoenix Channel
export function sendCloudEvent(jsonString) {
  if (window.webUiChannel) {
    window.webUiChannel.push("cloudevent", { event: jsonString })
      .receive("ok", () => console.log("CloudEvent sent"))
      .receive("error", (reason) => console.error("Send failed:", reason));
  }
}

// Receive CloudEvent from Phoenix Channel
function setupCloudEventReceiver(elmApp) {
  if (window.webUiChannel) {
    window.webUiChannel.on("cloudevent", (payload) => {
      elmApp.ports.receiveCloudEvent.send(payload.event);
    });
  }
}
```

## Error Handling

### Client-Side Errors

Errors from the server should follow this format:

```json
{
  "event": "error",
  "payload": {
    "reason": "invalid_specversion | missing_field | decode_error | unauthorized"
  }
}
```

### Server-Side Validation

Before processing incoming CloudEvents:

1. Validate JSON format
2. Validate CloudEvents specversion (must be "1.0")
3. Validate required fields (id, source, type, data)
4. Validate data content type
5. Check authorization for the topic scope

## Security Considerations

1. **Topic Authorization**: Implement `join/3` authorization checks
2. **Rate Limiting**: Add per-client rate limits for event publishing
3. **Input Validation**: Always validate incoming CloudEvents before processing
4. **Extension Sanitization**: Validate extension attributes against allowlist
5. **Message Size Limits**: Enforce maximum payload sizes

## Testing

### Unit Tests

```elixir
# Test incoming CloudEvent handling
test "handle_in/3 decodes valid CloudEvent" do
  event = WebUi.CloudEvent.new!(source: "/test", type: "com.test", data: %{})
  json = WebUi.CloudEvent.to_json!(event)

  assert {:reply, {:ok, _}, socket} =
    WebUi.EventChannel.handle_in("cloudevent", %{"event" => json}, socket)
end

# Test error handling
test "handle_in/3 returns error for invalid CloudEvent" do
  assert {:reply, {:error, _}, socket} =
    WebUi.EventChannel.handle_in("cloudevent", %{"event" => "invalid"}, socket)
end
```

### Integration Tests

```elixir
# Use Phoenix.ChannelTest for full stack testing
test "client can send and receive CloudEvents", %{socket: socket} do
  # Push event
  ref = push(socket, "cloudevent", %{
    event: ~s({"specversion":"1.0","id":"test","source":"/test","type":"com.test","data":{}})
  })

  # Assert reply
  assert_reply ref, :ok, _

  # Broadcast can be tested similarly
end
```

## Performance Considerations

1. **JSON Encoding**: CloudEvents are encoded as JSON strings within Phoenix payloads
2. **Compression**: Consider Phoenix transport compression for large payloads
3. **Batching**: Multiple CloudEvents can be sent in a single Phoenix message using an array
4. **Heartbeat**: Configure Phoenix heartbeat for connection health monitoring

## Migration Path

When implementing Phase 3:

1. Create `WebUi.EventChannel` module
2. Add channel route to router: `channel "events:*", WebUi.EventChannel`
3. Implement join authorization
4. Implement `handle_in/3` for incoming CloudEvents
5. Implement `handle_out/3` for outgoing CloudEvents
6. Add JavaScript interop layer
7. Update Elm ports to use the channel

## References

- Phoenix Channels Documentation: https://hexdocs.pm/phoenix/channels.html
- CloudEvents Spec: https://github.com/cloudevents/spec/blob/v1.0.1/cloudevents/spec.md
- WebUI CloudEvent Module: lib/web_ui/cloud_event.ex
