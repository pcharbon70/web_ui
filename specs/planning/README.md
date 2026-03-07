# WebUi Architecture Execution Plan Index

This directory contains a phased implementation plan for executing the current `web_ui` architecture and governance baseline.

The plan aligns to:
- `specs/topology.md`
- `specs/design.md`
- `specs/contracts/*`
- `specs/events/*`
- `specs/conformance/*`
- `rfcs/*`

## Phase Files
1. [Phase 1 - Transport Backbone and CloudEvent Boundary](./phase-01-transport-backbone-and-cloudevent-boundary.md): implement endpoint/router/channel foundations and canonical websocket naming.
2. [Phase 2 - Elm Runtime Bootstrap and UI Loop](./phase-02-elm-runtime-bootstrap-and-ui-loop.md): implement deterministic Elm bootstrap, websocket command flow, and JS interop isolation.
3. [Phase 3 - Runtime Authority Integration and Service Outcomes](./phase-03-runtime-authority-integration-and-service-outcomes.md): implement runtime dispatch, typed result normalization, and context continuity.
4. [Phase 4 - Widget Catalog Parity and Registry Foundation](./phase-04-widget-catalog-parity-and-registry-foundation.md): implement built-in widget parity, descriptors, and deterministic render contracts.
5. [Phase 5 - Widget Event Contracts and Elm Bindings](./phase-05-widget-event-contracts-and-elm-bindings.md): implement event catalog, widget event matrix wiring, and Elm message mappings.
6. [Phase 6 - Custom Widget Extension Governance](./phase-06-custom-widget-extension-governance.md): implement custom widget registration, validation, and built-in override protections.
7. [Phase 7 - Observability and Correlation Baseline](./phase-07-observability-and-correlation-baseline.md): implement event-envelope observability and mandatory metric coverage.
8. [Phase 8 - Conformance Scenario Implementation and Automation](./phase-08-conformance-scenario-implementation-and-automation.md): implement SCN coverage with deterministic conformance automation.
9. [Phase 9 - RFC Intake and Spec Governance Operations](./phase-09-rfc-intake-and-spec-governance-operations.md): operationalize RFC authoring, governance validation, and spec generation workflows.
10. [Phase 10 - First Implemented Slice and Release Readiness](./phase-10-first-implemented-slice-and-release-readiness.md): ship a first end-to-end slice with release gates and production-readiness checks.

## Shared Conventions
- Numbering:
  - Phases: `N`
  - Sections: `N.M`
  - Tasks: `N.M.K`
  - Subtasks: `N.M.K.L`
- Tracking:
  - Every phase, section, task, and subtask uses Markdown checkboxes (`[ ]`).
- Description requirement:
  - Every phase, section, and task starts with a short description paragraph.
- Integration-test requirement:
  - Each phase ends with a final integration-testing section.

## Shared Assumptions and Defaults
- `WebUi.*` naming is canonical for runtime modules.
- CloudEvents-shaped envelopes are the canonical transport payload.
- Runtime/domain state authority remains server-side.
- Elm is the canonical deterministic UI runtime.
- Widget baseline parity with `term_ui` is normative for built-ins.
- Governance and conformance docs are mandatory before merge.
