# Counter Example

Runnable counter application using the parent `web_ui` library.

## Status

Current implemented behavior:
- Interactive counter UI at `/counter` (Elm SPA route)
- CloudEvent commands sent over Phoenix channels
- Backend state managed by `CounterExample.CounterServer`
- Counter command/event mapping handled by `CounterExample.CounterEventHandler`
- Example app wired through `WebUi.EventChannel` `event_handler` callback

Architecture decision (Phase 0):
- Long-term canonical path is `WebUi.ServerAgentDispatcher` with `WebUi.ServerAgents.CounterAgent`
- The explicit `event_handler` callback remains temporarily for compatibility during phased migration
- Decision record: [`../../notes/architecture/decision-003-counter-example-dispatch-path.md`](../../notes/architecture/decision-003-counter-example-dispatch-path.md)

Roadmap details remain in [`PLAN.md`](./PLAN.md).

## Event Lifecycle (Current)

1. User clicks a counter command button (`increment`, `decrement`, `reset`).
2. Elm builds a CloudEvent (`source = urn:webui:examples:counter:client`) and sends it over the `events:lobby` channel.
3. `WebUi.EventChannel` validates the CloudEvent envelope.
4. Because `event_handler` is configured in the example, `CounterExample.CounterEventHandler.handle_cloudevent/2` is invoked.
5. The handler maps event type to operation and calls `CounterExample.CounterServer.apply_operation/1`.
6. The handler returns a `com.webui.counter.state_changed` CloudEvent with:
   - `data.count`
   - `data.operation`
   - `data.correlation_id` (when incoming event id is present)
7. `WebUi.EventChannel` broadcasts the response event to subscribed clients.
8. Elm updates UI state from `state_changed.data.count`.
9. On reconnect, Elm sends `com.webui.counter.sync` to converge with server state.

## Event Contract (Phase 1)

Contract source of truth:
- `CounterExample.EventContract` (`examples/counter/lib/counter_example/event_contract.ex`)

Specversion:
- Only CloudEvents `specversion = "1.0"` are supported.
- `WebUi.EventChannel` enforces required CloudEvent envelope fields and specversion validation before dispatch.
- `CounterExample.CounterEventHandler` returns `:unhandled` for unsupported specversion values.

Command event types:
- `com.webui.counter.increment`
- `com.webui.counter.decrement`
- `com.webui.counter.reset`
- `com.webui.counter.sync`

Response event type:
- `com.webui.counter.state_changed`

Source URIs:
- Client command source: `urn:webui:examples:counter:client`
- Server response source: `urn:webui:examples:counter`

Command envelope field expectations:
- Required: `specversion`, `id`, `source`, `type`
- Optional: `data`, `time`

`state_changed.data` field expectations:
- Required: `count`, `operation`
- Optional: `correlation_id`

Correlation id behavior:
- When incoming command contains `id`, response includes `data.correlation_id = <incoming id>`.
- When incoming command `id` is missing or non-binary, `data.correlation_id` is omitted.

Unknown/unsupported behavior:
- Unknown counter command types return `:unhandled`.
- Unsupported specversion values return `:unhandled`.

## Run

```bash
# from repo root (one-time for frontend assets)
mix setup
mix assets.build --force

# then run the example app
cd examples/counter
mix deps.get
mix server
```

Then open [http://localhost:4100](http://localhost:4100).

Open [http://localhost:4100/counter](http://localhost:4100/counter) for the
counter page.

## Test

```bash
cd examples/counter
mix test
```

## Notes

- This example depends on the local parent repo via `{:web_ui, path: "../.."}`.
- The app boots `WebUi.Endpoint` in dev via `config/dev.exs`.
