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
| `SCN-013` | Session-resume replay idempotency | Repeated disconnect loops preserve one pending resume join command per topic. |
| `SCN-014` | Retry storm containment | Retry paths apply deterministic backoff and fail closed when retry budget is exhausted. |
| `SCN-015` | Metric rejection joinability resilience | Observability metric rejections preserve correlation context and runtime event integrity. |
| `SCN-016` | Timeout/retry/cancel terminal determinism | Timeout and recovery chains converge to deterministic terminal UI state and retry reset. |
| `SCN-017` | Burst dispatch ordering determinism | Burst widget interactions preserve monotonic dispatch sequence through runtime, transport, and replay. |
| `SCN-018` | Outcome hint reconciliation continuity | Success outcomes preserve normalized `ui_hints` and UI reconciliation applies/clears hints deterministically. |
