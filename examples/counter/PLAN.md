# Counter Example Plan (Rebaselined)

**Last Updated:** 2026-02-18
**Owner:** WebUi maintainers
**Scope:** `examples/counter` plus required integration points in the parent `web_ui` library

---

## 1. Baseline Snapshot (Verified)

This plan is based on the current repository state, not the previous archived Phase-8 template.

### Current Working Behavior

- Counter page is reachable at `/counter` through Elm SPA routing.
- Counter commands are sent as CloudEvents over Phoenix channels.
- Counter backend state is managed by `CounterExample.CounterServer`.
- Counter event mapping is currently implemented in `CounterExample.CounterEventHandler`.
- Example app config wires `WebUi.EventChannel` to the custom event handler callback.

### Current Test Baseline

- `examples/counter` suite: **9 tests passing** (run on 2026-02-18).
- Counter example tests currently cover:
  - Counter state operations (`increment`, `decrement`, `reset`, `sync`)
  - Event handler mapping and `state_changed` response shape
  - Basic library integration check (`WebUi.Endpoint` load)

### Known Gaps

- Existing plan file was written for pre-migration modules (`WebUI.Agent`, old architecture) and is now obsolete.
- No browser-level E2E coverage for full user flow and reconnection UX.
- No explicit contract document for counter event schema and expected error behavior.
- No release gate/checklist for the example as a long-term reference app.

---

## 2. North-Star Outcomes

1. Keep the counter example runnable and stable as the canonical WebUi reference app.
2. Align implementation and docs with current Jido-based internals (no stale API references).
3. Add enough automated coverage to detect regressions across Elm <-> JS <-> Channel <-> backend state.
4. Provide clear release criteria so the example stays trustworthy across future refactors.

---

## 3. Phased Execution Plan

## Phase 0 - Rebaseline and Alignment

**Objective:** Remove stale planning assumptions and define the target architecture for this example.

### Tasks

- [ ] 0.1 Replace obsolete plan references with current architecture (this document).
- [ ] 0.2 Update `examples/counter/README.md` status section to match real implementation details.
- [ ] 0.3 Document event lifecycle in one place (incoming command -> operation -> `state_changed` event).
- [ ] 0.4 Decide and document the long-term integration strategy for the example:
  - Keep explicit `event_handler` callback in example config, or
  - Move example to the server-agent dispatcher path.
- [ ] 0.5 Add a small architecture note under `notes/` that records the decision and rationale.

### Exit Criteria

- [ ] Plan, README, and architecture note all agree on current behavior.
- [ ] No references remain to removed pre-migration APIs in counter example docs.

### Deliverables

- [ ] Updated `examples/counter/PLAN.md`
- [ ] Updated `examples/counter/README.md`
- [ ] New architecture note (location under `notes/`)

---

## Phase 1 - Event Contract Hardening

**Objective:** Make counter event semantics explicit and testable.

### Tasks

- [ ] 1.1 Define a single source of truth for counter event constants:
  - `com.webui.counter.increment`
  - `com.webui.counter.decrement`
  - `com.webui.counter.reset`
  - `com.webui.counter.sync`
  - `com.webui.counter.state_changed`
- [ ] 1.2 Standardize source URIs for client and server events.
- [ ] 1.3 Document required/optional `data` fields for each event type.
- [ ] 1.4 Formalize correlation-id behavior (`incoming id` -> `state_changed.data.correlation_id`).
- [ ] 1.5 Define behavior for unknown/unsupported event types.
- [ ] 1.6 Add explicit specversion handling expectations (`"1.0"` wire format).

### Test Tasks

- [ ] 1.7 Add focused tests for event type constant usage (prevent typo regressions).
- [ ] 1.8 Add tests for correlation-id presence/absence behavior.
- [ ] 1.9 Add tests for unknown event type outcomes (`:unhandled` path).
- [ ] 1.10 Add tests for event payload shape consistency.

### Exit Criteria

- [ ] Event contract is documented and enforced by tests.
- [ ] Counter example and WebUi channel code agree on specversion and field requirements.

### Deliverables

- [ ] Protocol/contract module and tests in `examples/counter/lib/counter_example/`
- [ ] Contract section in `examples/counter/README.md`

---

## Phase 2 - Backend Integration Refinement

**Objective:** Reduce integration ambiguity and harden backend behavior.

### Tasks

- [ ] 2.1 Keep backend operation logic centralized in one place (no duplicated operation mapping).
- [ ] 2.2 Ensure deterministic startup behavior for counter state process in all envs.
- [ ] 2.3 Add guardrails for invalid input payloads and unexpected runtime errors.
- [ ] 2.4 Add structured logging fields for operation, count, and correlation id.
- [ ] 2.5 Add telemetry hooks for command processing and error paths.
- [ ] 2.6 Validate config behavior in `dev`, `test`, and `prod` example configs.

### Optional Migration Track (if selected in Phase 0)

- [ ] 2.7 Introduce/enable server-agent dispatcher path for this example.
- [ ] 2.8 Remove direct event-handler callback dependency if server-agent path fully covers needs.
- [ ] 2.9 Preserve backward compatibility or explicitly document breaking changes.

### Test Tasks

- [ ] 2.10 Add tests for startup/restart behavior of counter state process.
- [ ] 2.11 Add tests for malformed event payload handling.
- [ ] 2.12 Add tests for concurrent command calls and deterministic count results.
- [ ] 2.13 Add tests asserting structured error responses/logging boundaries.

### Exit Criteria

- [ ] Backend command processing is deterministic and resilient to bad input.
- [ ] Config and startup behavior are verified in all target environments.

### Deliverables

- [ ] Updated backend modules in `examples/counter/lib/counter_example/`
- [ ] Expanded `examples/counter/test/counter_server_test.exs`
- [ ] Expanded `examples/counter/test/counter_event_handler_test.exs`

---

## Phase 3 - Frontend and UX Robustness

**Objective:** Ensure counter page behavior remains clear and stable under real connection conditions.

### Tasks

- [ ] 3.1 Verify command buttons remain correctly gated by connection state.
- [ ] 3.2 Improve connection-state messaging for reconnect/error states.
- [ ] 3.3 Ensure first-load sync behavior is deterministic after reconnect.
- [ ] 3.4 Add explicit handling/display for server error events.
- [ ] 3.5 Validate accessibility semantics (button labels, focus behavior, keyboard flow).
- [ ] 3.6 Validate responsive layout behavior on mobile and desktop breakpoints.

### Test Tasks

- [ ] 3.7 Add/expand Elm tests for state transitions tied to CloudEvent payloads.
- [ ] 3.8 Add tests for reconnect-triggered sync behavior.
- [ ] 3.9 Add tests for malformed event payload tolerance on the client.

### Exit Criteria

- [ ] Counter UI remains usable during connect/reconnect/disconnect transitions.
- [ ] UI state always converges to server truth after reconnect.

### Deliverables

- [ ] Updates under `assets/elm/src/Main.elm` and related Elm tests
- [ ] Optional styling and copy improvements in shared UI assets

---

## Phase 4 - End-to-End and Multi-Client Coverage

**Objective:** Add regression coverage for real-world flows not fully covered today.

### Tasks

- [ ] 4.1 Add browser-level E2E test for `load -> connect -> increment/decrement/reset`.
- [ ] 4.2 Add browser-level reconnect scenario test.
- [ ] 4.3 Add multi-client synchronization test (two sessions/tabs).
- [ ] 4.4 Add malformed-event negative-path test at channel boundary.
- [ ] 4.5 Add a lightweight stress test for rapid command bursts.

### Tooling Tasks

- [ ] 4.6 Choose and configure browser E2E framework (Playwright or Wallaby).
- [ ] 4.7 Add repeatable test commands and CI-friendly setup docs.
- [ ] 4.8 Ensure E2E tests are deterministic in local and CI runs.

### Exit Criteria

- [ ] E2E suite covers at least the 5 core acceptance flows:
  - Load and connect
  - Command round-trip
  - Reset behavior
  - Multi-client sync
  - Reconnect recovery

### Deliverables

- [ ] E2E test suite and runner docs under `examples/counter/`
- [ ] CI command examples in `examples/counter/README.md`

---

## Phase 5 - Documentation and Developer Experience

**Objective:** Make the example easy to run, understand, and extend.

### Tasks

- [ ] 5.1 Rewrite README to include:
  - Architecture diagram for current stack
  - Event contract reference
  - Run and test commands
  - Troubleshooting section (websocket, config, asset build)
- [ ] 5.2 Add a "how to extend" section (adding a new counter command/event).
- [ ] 5.3 Add a "debugging" section with expected logs and common failure modes.
- [ ] 5.4 Ensure all docs use current Jido/WebUi naming and terminology.

### Exit Criteria

- [ ] A new contributor can run, test, and understand the example using README only.

### Deliverables

- [ ] Updated `examples/counter/README.md`
- [ ] Optional `examples/counter/ARCHITECTURE.md` if README becomes too dense

---

## Phase 6 - Release Gate and Ongoing Maintenance

**Objective:** Establish objective quality gates before marking the example complete.

### Release Checklist

- [ ] 6.1 Example tests pass (`mix test` in `examples/counter`).
- [ ] 6.2 Counter-related WebUi integration tests pass in parent project.
- [ ] 6.3 E2E smoke flow passes locally.
- [ ] 6.4 No stale architecture references remain in docs.
- [ ] 6.5 Runbook for common failures is present and validated.

### Maintenance Checklist

- [ ] 6.6 Add a periodic doc drift check (plan vs implementation).
- [ ] 6.7 Keep event contract examples synchronized with actual payloads.
- [ ] 6.8 Update this plan when architecture changes (especially channel dispatch path).

### Exit Criteria

- [ ] Counter example can be treated as a stable reference implementation.

---

## 4. Cross-Phase Risks and Mitigations

- **Risk:** Divergence between example handler path and server-agent dispatcher path.
  - **Mitigation:** Decide one canonical path in Phase 0 and document it clearly.
- **Risk:** Hidden regressions across Elm/JS/channel boundaries.
  - **Mitigation:** Add browser E2E and reconnect tests in Phase 4.
- **Risk:** Contract drift in event payload fields.
  - **Mitigation:** Centralize constants and payload assertions in Phase 1.
- **Risk:** Documentation becoming stale after refactors.
  - **Mitigation:** Include release/maintenance checks in Phase 6.

---

## 5. Milestone Summary

- **M0 (Planning Aligned):** Phase 0 complete.
- **M1 (Contract Stable):** Phases 1-2 complete.
- **M2 (UX + E2E Stable):** Phases 3-4 complete.
- **M3 (Reference App Ready):** Phases 5-6 complete.

---

## 6. Immediate Next Actions

1. Complete Phase 0 architecture decision (event-handler vs server-agent canonical path).
2. Implement Phase 1 event contract module + tests.
3. Start Phase 2 backend hardening from the selected architecture path.
