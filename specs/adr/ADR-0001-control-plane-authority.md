# ADR-0001: Control-Plane Authority for WebUi Runtime Boundaries

## Status

Accepted

## Context

`web_ui` integrates multiple execution surfaces (Elm, Phoenix channels, optional JS interop, and host runtime services).
Without explicit authority boundaries, runtime behavior can drift and create split ownership for state and policy decisions.

## Decision

1. Browser UI state authority is Elm runtime only.
2. Domain/runtime state authority is server-side host runtime services (Jido agents/actions).
3. `web_ui` transport modules are orchestration boundaries and MUST NOT become domain-state owners.
4. JS interop is an extension seam and MUST remain non-authoritative.
5. All client/server boundary payloads MUST use the canonical CloudEvents-shaped envelope.

## Consequences

- Ownership boundaries are explicit and reviewable.
- Transport and interop layers remain decoupled from product-domain authority.
- Architecture, contract, and conformance docs can enforce the same control-plane model.

## Related Requirements

`REQ-CP-001` through `REQ-CP-010` (to be finalized in contract docs)
