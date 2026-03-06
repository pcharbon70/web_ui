# Scenario Catalog

Canonical validation scenarios for the current baseline contract layer.

| Scenario ID | Name | Summary |
|---|---|---|
| `SCN-001` | Control-plane ownership consistency | Runtime modules map to one canonical plane assignment without conflicts. |
| `SCN-002` | Transport boundary authority | Endpoint/router/channel orchestration does not mutate domain state. |
| `SCN-003` | CloudEvent envelope validation | Ingress rejects malformed envelopes with typed protocol errors. |
| `SCN-004` | Correlation continuity | Correlation and request IDs are preserved ingress -> runtime -> egress. |
| `SCN-005` | Typed service outcome normalization | Runtime operations return typed success/error envelopes only. |
| `SCN-006` | Observability minimum baseline | Required event envelopes and metric families are emitted and joinable. |
| `SCN-007` | Built-in widget catalog parity | Built-in widget catalog exactly matches the public `term_ui` widget baseline list. |
| `SCN-008` | Widget descriptor completeness | Built-in widget descriptors include required schema metadata and stable IDs. |
| `SCN-009` | Custom widget registration validation | Invalid or duplicate custom widget registrations fail closed with typed errors. |
| `SCN-010` | Built-in override protection | Custom registrations cannot replace reserved built-in widget IDs by default. |
| `SCN-011` | Widget event correlation continuity | Widget render and lifecycle events preserve `correlation_id` and `request_id`. |
| `SCN-012` | Deterministic widget render behavior | Equivalent widget descriptor + props + state inputs produce equivalent render outputs. |
| `SCN-013` | IUR layout compatibility traversal | `VBox`/`HBox` IUR trees traverse deterministically and preserve declared child ordering. |
| `SCN-014` | IUR signal handler normalization | Accepted signal handler shapes normalize consistently; unsupported shapes fail closed. |
| `SCN-015` | Standard signal compatibility mapping | Standard signal names map to canonical `unified.*` signal types and route-key precedence is honored. |
| `SCN-016` | IUR interpretation fail-closed boundary | Invalid/unsupported IUR nodes emit typed errors and required interpreter observability events. |
