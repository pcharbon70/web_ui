# Phase 5 Review Fixes and Improvements

**Feature Branch:** `feature/phase-5-review-fixes`
**Created:** 2025-02-01
**Status:** IN PROGRESS

## Overview

Fix all blockers, concerns, and implement suggested improvements from the Phase 5 comprehensive review.

## Items to Address

### 🚨 Blockers (Must Fix) - 3 items

- [ ] 1.1 Fix module naming inconsistency (`WebUI.*` → `WebUi.Agent.*`)
- [ ] 1.2 Fix agent restart auto-re-registration
- [ ] 1.3 Fix/clarify sync dispatch response collection

### ⚠️ Concerns (Should Address) - 10 items

- [ ] 2.1 Add timeouts to all GenServer.call/3 invocations
- [ ] 2.2 Add ETS table size limits and cleanup
- [ ] 2.3 Fix race conditions in tests (replace Process.sleep)
- [ ] 2.4 Add error path tests for supervisor
- [ ] 2.5 Clarify partitioning support (implement or remove)
- [ ] 2.6 Implement backpressure mechanism
- [ ] 2.7 Add comprehensive telemetry
- [ ] 2.8 Implement priority queuing
- [ ] 2.9 Fix process monitor leakage
- [ ] 2.10 Standardize telemetry event naming

### 💡 Suggestions (Nice to Have) - 7 items

- [ ] 3.1 Extract common test agents to helper module
- [ ] 3.2 Standardize source URN convention
- [ ] 3.3 Add agent lifecycle hooks
- [ ] 3.4 Document agent pool pattern (reference implementation)
- [ ] 3.5 Document event replay pattern (reference implementation)
- [ ] 3.6 Document event schema validation pattern
- [ ] 3.7 Add pattern matching edge case tests

## Implementation Plan

### Phase 1: Blockers (Critical)
1. Rename all `WebUI.*` modules to `WebUi.Agent.*`
2. Implement auto-re-registration on agent restart
3. Clarify sync dispatch behavior and update documentation

### Phase 2: Concerns (High Priority)
1. Add timeout parameter to all GenServer.call
2. Implement ETS table limits and cleanup
3. Replace Process.sleep with proper assertions
4. Add comprehensive error path tests
5. Implement or clarify partitioning
6. Add basic backpressure
7. Enhance telemetry coverage
8. Implement priority queue
9. Fix monitor cleanup
10. Standardize telemetry names

### Phase 3: Suggestions (Medium Priority)
1. Create test support module
2. Standardize URN convention
3. Add lifecycle hooks to behaviour
4. Document patterns for pools/replay/schemas
5. Add edge case tests

## Files to Modify

**Implementation Files:**
- `lib/web_ui/agent.ex` → Rename and fix
- `lib/web_ui/agent_supervisor.ex` → Rename and fix
- `lib/web_ui/agent_registry.ex` → Rename and fix
- `lib/web_ui/agent_dispatcher.ex` → Rename and fix
- `lib/web_ui/agent_events.ex` → Rename and fix

**Test Files:**
- `test/web_ui/agent_test.exs` → Update references
- `test/web_ui/agent_supervisor_test.exs` → Update references and add tests
- `test/web_ui/agent_dispatcher_test.exs` → Update references
- `test/web_ui/agent_events_test.exs` → Update references
- `test/web_ui/agent_integration_test.exs` → Update references

**New Files:**
- `lib/web_ui/agent/registry.ex` - Renamed from agent_registry.ex
- `lib/web_ui/agent/supervisor.ex` - Renamed from agent_supervisor.ex
- `lib/web_ui/agent/dispatcher.ex` - Renamed from agent_dispatcher.ex
- `lib/web_ui/agent/events.ex` - Renamed from agent_events.ex
- `test/support/test_agents.ex` - Common test agents

## Status Log

- **2025-02-01**: Branch created, planning started
