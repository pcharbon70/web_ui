# Services and Libraries

## Purpose

This document catalogs planned runtime services and key libraries used by `web_ui`.

## Planned Core Runtime Modules

| Module | Responsibility | Ownership |
|---|---|---|
| `WebUi.Endpoint` | Serve assets and expose socket transport | `web_ui` |
| `WebUi.Router` | Route SPA entry points and transport endpoints | `web_ui` |
| `WebUi.Channel` | Receive/emit CloudEvents over WebSocket | `web_ui` |
| `WebUi.CloudEvent` | Envelope schema and encode/decode helpers | `web_ui` |
| `WebUi.Agent` | Integration helpers for runtime service handlers | `web_ui` |
| `WebUi.Component` | Shared component-level abstractions | `web_ui` |
| `WebUi.WidgetRegistry` | Built-in widget catalog + custom registration lifecycle | `web_ui` |
| `WebUi.Widget` | Widget descriptor + implementation behavior contract | `web_ui` |

## External Library Dependencies

| Library/Runtime | Role |
|---|---|
| Phoenix | HTTP endpoint, channels, websocket transport |
| Jido | Agent-based runtime orchestration |
| Elm | Browser-side deterministic UI runtime |
| Tailwind CSS | Utility-first styling layer |
| JavaScript runtime | Port-based interop boundary for browser-specific features |

## Contract Alignment

The modules above MUST align with:

- [service_contract.md](/Users/Pascal/code/unified/web_ui/specs/contracts/service_contract.md)
- [observability_contract.md](/Users/Pascal/code/unified/web_ui/specs/contracts/observability_contract.md)
- [control_plane_ownership_matrix.md](/Users/Pascal/code/unified/web_ui/specs/contracts/control_plane_ownership_matrix.md)
- [widget_system_contract.md](/Users/Pascal/code/unified/web_ui/specs/contracts/widget_system_contract.md)

## Initial Extension Seams

- Alternate transport adapters (if needed beyond Phoenix channels)
- Browser interop utilities through typed Elm ports
- Runtime event router plugins for host app domains
