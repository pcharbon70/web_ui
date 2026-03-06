# Spec Conformance Matrix

This matrix maps requirement families to owning contracts and canonical baseline scenarios.

| Requirement Family | Owning Contract | Primary Runtime Modules | Scenario Coverage |
|---|---|---|---|
| `REQ-CP-001`..`REQ-CP-010` | [control_plane_ownership_matrix.md](/Users/Pascal/code/unified/web_ui/specs/contracts/control_plane_ownership_matrix.md) | `WebUi.Endpoint`, `WebUi.Router`, `WebUi.Channel`, `WebUi.CloudEvent`, `WebUi.Agent`, `WebUi.Component`, `WebUi.WidgetRegistry`, `WebUi.Widget` | `SCN-001`, `SCN-002` |
| `REQ-SVC-001`..`REQ-SVC-010` | [service_contract.md](/Users/Pascal/code/unified/web_ui/specs/contracts/service_contract.md) | `WebUi.Endpoint`, `WebUi.Router`, `WebUi.Channel`, `WebUi.CloudEvent`, `WebUi.Agent`, `WebUi.Component`, `WebUi.WidgetRegistry`, `WebUi.Widget` | `SCN-003`, `SCN-004`, `SCN-005` |
| `REQ-OBS-001`..`REQ-OBS-010` | [observability_contract.md](/Users/Pascal/code/unified/web_ui/specs/contracts/observability_contract.md) | `WebUi.Channel`, `WebUi.CloudEvent`, `WebUi.Agent` | `SCN-004`, `SCN-006` |
| `REQ-WGT-001`..`REQ-WGT-010` | [widget_system_contract.md](/Users/Pascal/code/unified/web_ui/specs/contracts/widget_system_contract.md) | `WebUi.WidgetRegistry`, `WebUi.Widget`, `WebUi.Component`, `WebUi.Channel` | `SCN-007`, `SCN-008`, `SCN-009`, `SCN-010`, `SCN-011`, `SCN-012` |
| `REQ-IUR-001`..`REQ-IUR-010` | [iur_interpretation_contract.md](/Users/Pascal/code/unified/web_ui/specs/contracts/iur_interpretation_contract.md) | `WebUi.IUR.Interpreter`, `WebUi.WidgetRegistry`, `WebUi.Widget`, `WebUi.Channel` | `SCN-013`, `SCN-014`, `SCN-015`, `SCN-016` |

## Acceptance Mapping Rule

Every future AC-bearing component spec MUST map to at least one `REQ-*` family and one `SCN-*` scenario.

## Bootstrap Note

Current implementation is in architecture-contract bootstrap mode (no AC-bearing component specs yet).
This matrix establishes initial requirement-family and scenario-family alignment for early conformance planning.
