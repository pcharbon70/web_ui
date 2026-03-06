# Specs Index

## Architecture Summary

- `web_ui` is a reusable Elixir library for building event-driven web UIs with Elm, Phoenix, and Jido.
- The frontend is an Elm SPA styled with Tailwind and connected to backend runtime services through WebSockets.
- Client/server communication uses CloudEvents-shaped envelopes (`JidoSignal` compatible) as the canonical protocol.
- Runtime state authority stays server-side in Elixir/Jido agents; Elm is the canonical UI state authority in the browser.
- Optional JavaScript interop is isolated behind explicit Elm ports and typed event messages.
- Governance is enforced through specs contracts, conformance scenarios, and CI checks.

Normative language in this directory uses RFC-2119 terms: **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY**.

## Canonical Baselines

- [design.md](/Users/Pascal/code/unified/web_ui/specs/design.md)
- [topology.md](/Users/Pascal/code/unified/web_ui/specs/topology.md)
- [boundaries.md](/Users/Pascal/code/unified/web_ui/specs/boundaries.md)
- [control_planes.md](/Users/Pascal/code/unified/web_ui/specs/control_planes.md)
- [targets.md](/Users/Pascal/code/unified/web_ui/specs/targets.md)
- [services-and-libraries.md](/Users/Pascal/code/unified/web_ui/specs/services-and-libraries.md)

## Contract Layer

- [contracts/control_plane_ownership_matrix.md](/Users/Pascal/code/unified/web_ui/specs/contracts/control_plane_ownership_matrix.md)
- [contracts/service_contract.md](/Users/Pascal/code/unified/web_ui/specs/contracts/service_contract.md)
- [contracts/supervision_restart_contract.md](/Users/Pascal/code/unified/web_ui/specs/contracts/supervision_restart_contract.md)
- [contracts/turn_execution_contract.md](/Users/Pascal/code/unified/web_ui/specs/contracts/turn_execution_contract.md)
- [contracts/policy_authorization_contract.md](/Users/Pascal/code/unified/web_ui/specs/contracts/policy_authorization_contract.md)
- [contracts/scope_resolution_contract.md](/Users/Pascal/code/unified/web_ui/specs/contracts/scope_resolution_contract.md)
- [contracts/prompt_asset_contract.md](/Users/Pascal/code/unified/web_ui/specs/contracts/prompt_asset_contract.md)
- [contracts/persistence_replay_contract.md](/Users/Pascal/code/unified/web_ui/specs/contracts/persistence_replay_contract.md)
- [contracts/observability_contract.md](/Users/Pascal/code/unified/web_ui/specs/contracts/observability_contract.md)
- [contracts/eval_contract.md](/Users/Pascal/code/unified/web_ui/specs/contracts/eval_contract.md)
- [contracts/widget_system_contract.md](/Users/Pascal/code/unified/web_ui/specs/contracts/widget_system_contract.md)

## ADRs

- [adr/ADR-0001-control-plane-authority.md](/Users/Pascal/code/unified/web_ui/specs/adr/ADR-0001-control-plane-authority.md)

## Conformance

- [conformance/spec_conformance_matrix.md](/Users/Pascal/code/unified/web_ui/specs/conformance/spec_conformance_matrix.md)
- [conformance/scenario_catalog.md](/Users/Pascal/code/unified/web_ui/specs/conformance/scenario_catalog.md)
- [conformance/fault_recovery_and_determinism_hardening.md](/Users/Pascal/code/unified/web_ui/specs/conformance/fault_recovery_and_determinism_hardening.md)

## Planning

- [planning/README.md](/Users/Pascal/code/unified/web_ui/specs/planning/README.md)

## Operations

- [operations/README.md](/Users/Pascal/code/unified/web_ui/specs/operations/README.md)

## Governance Validation

Run the docs governance gate locally:

```bash
./scripts/validate_specs_governance.sh
```

Run the conformance harness locally:

```bash
./scripts/run_conformance.sh
```

or:

```bash
mix conformance
```

CI runs the same checks in:

- `.github/workflows/specs-governance.yml`
- `.github/workflows/conformance.yml`
