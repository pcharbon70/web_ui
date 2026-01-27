# ADR-001: Jido Dependency Selection

**Status:** Accepted
**Date:** 2025-01-27
**Context:** Phase 1 Implementation
**Related:** Concern 1 from Phase 1 Review

## Context

The planning document specified `jido_code ~> 0.1` as an optional dependency. The implementation uses `jido ~> 0.1` instead.

## Decision

Use `{:jido, "~> 0.1", optional: true}` in mix.exs instead of `jido_code`.

## Rationale

1. **Package Availability**: The `jido` package is the main public package available on Hex.pm for the Jido agent framework. `jido_code` may be an internal or development package name.

2. **Framework Integration**: Jido agents provide the core agent behavior, process management, and communication patterns needed for WebUI integration. Using the main `jido` package ensures access to the complete framework.

3. **Optional Dependency**: Jido remains optional because:
   - WebUI can function as a standalone library without Jido
   - Users who don't need agent functionality can omit the dependency
   - The `optional: true` flag allows graceful handling of missing jido

4. **Future Compatibility**: The `jido` package is designed to be the stable public API. Internal packages like `jido_code` may have different stability guarantees.

## Consequences

**Positive:**
- Access to full Jido agent framework capabilities
- Public package with documented API
- Optional dependency keeps WebUI lightweight

**Negative:**
- Slight deviation from planning document (documented here)
- May include additional Jido features not strictly needed

## Alternatives Considered

1. **Use jido_code**: Rejected due to package availability concerns
2. **Make jido required**: Rejected to maintain library flexibility
3. **No Jido integration**: Rejected as it would remove agent capabilities

## References

- Jido Framework: https://hex.pm/packages/jido
- Planning Document: notes/feature/section-2.1-cloudevent-struct.md
