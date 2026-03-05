# Counter Example

Runnable counter application using the parent `web_ui` library.

## Status

Current implemented behavior:
- Interactive counter UI at `/counter` (Elm SPA route)
- CloudEvent commands sent over Phoenix channels
- Backend state managed by `CounterExample.CounterServer`
- Counter command handling runs through `CounterExample.CounterAgent`
- Example app is wired through `WebUi.ServerAgentDispatcher` (no `event_handler` config dependency)

Architecture decision (Phase 0):
- Canonical path is `WebUi.ServerAgentDispatcher` with `CounterExample.CounterAgent`
- The dispatcher path is enabled as the primary runtime flow
- `CounterExample.CounterEventHandler` remains as a compatibility wrapper only
- Decision record: [`../../notes/architecture/decision-003-counter-example-dispatch-path.md`](../../notes/architecture/decision-003-counter-example-dispatch-path.md)

Roadmap details remain in [`PLAN.md`](./PLAN.md).

## Event Lifecycle (Current)

1. User clicks a counter command button (`increment`, `decrement`, `reset`).
2. Elm builds a CloudEvent (`source = urn:webui:examples:counter:client`) and sends it over the `events:lobby` channel.
3. `WebUi.EventChannel` validates the CloudEvent envelope.
4. `WebUi.EventChannel` converts the event to `Jido.Signal` and dispatches through `WebUi.ServerAgentDispatcher`.
5. Dispatcher routes the signal to `CounterExample.CounterAgent`.
6. Agent validates payload/data, maps event type to operation, and calls `CounterExample.CounterServer.apply_operation/1`.
7. Agent emits a `com.webui.counter.state_changed` signal mapped back to CloudEvent with:
   - `data.count`
   - `data.operation`
   - `data.correlation_id` (when incoming event id is present)
8. `WebUi.EventChannel` broadcasts the response event to subscribed clients.
9. Elm updates UI state from `state_changed.data.count`.
10. On reconnect, Elm sends `com.webui.counter.sync` to converge with server state.

## Event Contract (Phase 1)

Contract source of truth:
- `CounterExample.EventContract` (`examples/counter/lib/counter_example/event_contract.ex`)

Specversion:
- Only CloudEvents `specversion = "1.0"` are supported.
- `WebUi.EventChannel` enforces required CloudEvent envelope fields and specversion validation before dispatch.
- `CounterExample.CounterAgent` returns `:unhandled` for unknown command types.
- Compatibility callback `CounterExample.CounterEventHandler` returns `:unhandled` for unsupported specversion values.

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

## Backend Hardening (Phase 2)

- Startup is deterministic through `CounterServer.ensure_started/0` with restart-path coverage.
- Guardrails are applied for unsupported operations and malformed signal data.
- Structured logs include command `type`, `operation`, `count`, and `correlation_id`.
- Telemetry is emitted for success/error paths:
  - `[:counter_example, :counter_server, :operation, :stop | :error]`
  - `[:counter_example, :counter_agent, :command, :stop | :error]`

## Frontend UX Hardening (Phase 3)

- Counter command dispatch is gated by connection state in the UI update flow (not only button `disabled` attributes).
- Connection-state messaging explicitly covers `connecting`, `reconnecting`, `disconnected`, and `error` states.
- First connect/reconnect sets sync as pending and sends `com.webui.counter.sync` for deterministic convergence.
- Server-side channel errors are surfaced as client-visible `com.webui.counter.server_error` events.
- Counter page adds explicit accessibility semantics (`aria-live`, alert/status roles, control-group labeling, focus-visible affordances).
- Counter page layout and typography use responsive classes for mobile and desktop readability.

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

# from repo root, run frontend Elm tests
cd assets/elm
npx elm-test "tests/**/*Test.elm"
```

## Notes

- This example depends on the local parent repo via `{:web_ui, path: "../.."}`.
- The app boots `WebUi.Endpoint` in dev via `config/dev.exs`.
