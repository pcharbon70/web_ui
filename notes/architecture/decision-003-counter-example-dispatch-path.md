# ADR-003: Counter Example Canonical Dispatch Path

**Status:** Accepted
**Date:** 2026-03-05
**Context:** Counter example Phase 0 rebaseline
**Related:** `examples/counter/PLAN.md` Phase 0 task 0.4

## Context

The counter example currently handles command events through an explicit
`WebUi.EventChannel` callback configured in
`examples/counter/config/config.exs`:

- `event_handler: {CounterExample.CounterEventHandler, :handle_cloudevent}`

At the same time, the parent `web_ui` library now includes a server-agent
dispatch path (`WebUi.ServerAgentDispatcher`) and a counter component agent
(`WebUi.ServerAgents.CounterAgent`) for the same command family.

Keeping both paths long-term creates avoidable duplication:
- event-type to operation mapping exists in two places
- payload-shape and correlation-id behavior can drift
- example behavior can diverge from the library's preferred architecture

## Decision

Use the server-agent dispatcher path as the canonical long-term architecture
for the counter example.

Specifically:
1. The target runtime path is `WebUi.EventChannel` -> `WebUi.ServerAgentDispatcher`
   -> `WebUi.ServerAgents.CounterAgent` -> `com.webui.counter.state_changed`.
2. The existing explicit `event_handler` callback remains temporarily for
   compatibility while phased work is completed.
3. The callback path will be removed once migration tasks are complete
   (planned in Phase 2).

## Rationale

1. Alignment with current `web_ui` internals:
   server-agent dispatch is the architecture now used by the parent library.
2. Lower maintenance overhead:
   one canonical command-handling path reduces duplicate mapping logic.
3. Stronger contract consistency:
   command and response payload behavior is less likely to drift across
   integrations.
4. Better long-term extensibility:
   new component behaviors can follow the same dispatcher/agent pattern.

## Consequences

Positive:
- Counter example aligns with the parent architecture direction.
- Less risk of contract drift between example and library internals.
- Cleaner migration path for future component examples.

Tradeoff:
- Short-term dual-path period until migration is complete.
- Migration requires careful test coverage to avoid behavior regressions.

## Phase Implications

- Phase 1: define event contract constants and expectations so both paths
  are measured against the same semantics.
- Phase 2: migrate the example runtime path to server-agent dispatch and
  remove explicit `event_handler` config once parity is verified.

## References

- `examples/counter/PLAN.md`
- `examples/counter/config/config.exs`
- `examples/counter/lib/counter_example/counter_event_handler.ex`
- `lib/web_ui/channels/event_channel.ex`
- `lib/web_ui/server_agent_dispatcher.ex`
- `lib/web_ui/server_agents/counter_agent.ex`
