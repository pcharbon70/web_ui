# Migration from WebUi.* to Jido

**Date:** 2026-02-03

## Summary

WebUI has been consolidated to use Jido for agent and event handling. The following WebUI modules have been **removed** and replaced with their Jido equivalents:

## Removed Modules

| WebUi Module | Jido Replacement | Notes |
|--------------|------------------|-------|
| `WebUi.Agent` | `Jido.Agent.Server` | Full GenServer-based agent runtime |
| `WebUi.Agent.Dispatcher` | `Jido.Signal.Bus` | Event bus with pubsub, journaling |
| `WebUi.Agent.Registry` | `Jido.Signal.Bus` | Built-in subscription management |
| `WebUi.Agent.Supervisor` | `Jido.Agent.Server.Supervisor` | Built-in supervisor |
| `WebUi.Dispatcher` | `Jido.Signal.Dispatch` | Signal delivery with adapters |
| `WebUi.Dispatcher.Handler` | `Jido.Signal.Dispatch.Adapter` | Adapter behaviour |
| `WebUi.Dispatcher.Registry` | `Jido.Signal.Bus` | Subscription registry |
| `WebUi.CloudEvent` | `Jido.Signal` | CloudEvents v1.0.2 compliant |
| `WebUi.CloudEvent.Validator` | `Jido.Signal` | Built-in validation |

## API Migration

### Creating Signals (CloudEvents)

**Before:**
```elixir
event = WebUi.CloudEvent.new!(
  source: "/my/source",
  type: "com.example.event",
  data: %{message: "Hello"}
)
```

**After:**
```elixir
signal = Jido.Signal.new!(
  source: "/my/source",
  type: "com.example.event",
  data: %{message: "Hello"}
)
```

### Agent Implementation

**Before:**
```elixir
defmodule MyAgent do
  use WebUi.Agent
  use GenServer

  def subscribe_to, do: ["com.example.*"]

  @impl true
  def init(opts), do: {:ok, %{}}

  @impl true
  def handle_cloud_event(event, state), do: {:ok, state}

  @impl true
  def handle_cast({:cloudevent, event}, state) do
    # Handle event
    {:noreply, state}
  end
end
```

**After:**
```elixir
defmodule MyAgent do
  use Jido.Agent.Server

  def handle_signal(%Jido.Signal{type: "com.example.event"} = signal, state) do
    # Process signal
    {:ok, state}
  end
end
```

### Event Dispatch

**Before:**
```elixir
{:ok, sub_id} = WebUi.Dispatcher.subscribe("com.example.*", handler)
:ok = WebUi.Dispatcher.dispatch(event)
```

**After:**
```elixir
{:ok, bus} = Jido.Signal.Bus.start_link()
{:ok, sub_id} = Jido.Signal.Bus.subscribe(bus, "com.example.*", dispatch: {:pid, target: self()})
:ok = Jido.Signal.Bus.publish(bus, [signal])
```

## Why This Change?

1. **CloudEvents Compliance:** `Jido.Signal` implements CloudEvents v1.0.2 (same spec as WebUi.CloudEvent)
2. **No Conflicting Behaviours:** `Jido.Agent.Server` is a proper GenServer - no need for dual `use` statements
3. **More Features:** Jido provides skills, actions, state machines, telemetry, and more
4. **Single System:** One agent system reduces confusion and maintenance burden
5. **Better Performance:** Jido has optimized routing with trie-based pattern matching

## Files Deleted

### Library Files (~2500 lines removed)
- `lib/web_ui/agent.ex` (530 lines)
- `lib/web_ui/agent/dispatcher.ex`
- `lib/web_ui/agent/events.ex`
- `lib/web_ui/agent/registry.ex`
- `lib/web_ui/agent/supervisor.ex`
- `lib/web_ui/dispatcher.ex` (354 lines)
- `lib/web_ui/dispatcher/handler.ex` (189 lines)
- `lib/web_ui/dispatcher/registry.ex` (295 lines)
- `lib/web_ui/cloud_event.ex` (1131 lines)
- `lib/web_ui/cloud_event/` directory

### Test Files (~1500 lines removed)
- `test/web_ui/agent_test.exs`
- `test/web_ui/agent_dispatcher_test.exs`
- `test/web_ui/agent_supervisor_test.exs`
- `test/web_ui/agent_events_test.exs`
- `test/web_ui/agent_integration_test.exs`
- `test/web_ui/dispatcher_test.exs`
- `test/web_ui/dispatcher/registry_test.exs`
- `test/web_ui/cloud_event_test.exs`
- `test/web_ui/cloud_event_builders_test.exs`
- `test/web_ui/cloud_event_integration_test.exs`
- `test/web_ui/cloud_event_json_test.exs`
- `test/web_ui/cloud_event_validator_test.exs`

## Updated Files

- `mix.exs` - Made `:jido` dependency required (was optional)
- `lib/web_ui/channels/event_channel.ex` - Updated to use `Jido.Signal`
- `test/web_ui/phase3_integration_test.exs` - Updated references, skipped dispatcher tests

## Jido Resources

- **Jido.Signal Documentation:** https://hexdocs.pm/jido_signal/Jido.Signal.html
- **Jido.Agent.Server:** https://hexdocs.pm/jido/Jido.Agent.Server.html
- **Jido.Signal.Bus:** https://hexdocs.pm/jido/Jido.Signal.Bus.html
- **Jido.Signal.Dispatch:** https://hexdocs.pm/jido/Jido.Signal.Dispatch.html
