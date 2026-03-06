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
