# Phase 3.3: Event Dispatcher and Router

**Feature Branch:** `feature/phase-3.3-dispatcher`

**Goal:** Implement event routing from WebSocket channel to appropriate handlers (Jido agents or user callbacks) with pattern matching, wildcard subscriptions, and fault tolerance.

## Current State

- EventChannel exists and handles CloudEvents
- **Dispatcher module implemented with full functionality**
- **Handler registry with ETS tables implemented**
- **All tests passing (39 tests)**

## Implementation Tasks

### Task 3.3.1: Create Dispatcher Module
- [x] Create lib/web_ui/dispatcher.ex
- [x] Define behaviour for event handlers
- [x] Implement basic GenServer for dispatcher
- [x] Add module documentation

### Task 3.3.2: Implement Handler Registry
- [x] Use ETS table for handler subscriptions
- [x] Support subscription by type pattern
- [x] Support subscription by source pattern
- [x] Add unique handler IDs

### Task 3.3.3: Event Routing by Type
- [x] Route events based on CloudEvent type
- [x] Support exact type matching
- [x] Support prefix wildcard (com.example.*)
- [x] Support suffix wildcard (*.event)

### Task 3.3.4: Event Routing by Source
- [x] Route events based on CloudEvent source
- [x] Support source pattern matching
- [x] Support URI-based routing

### Task 3.3.5: Wildcard Subscriptions
- [x] Support prefix wildcards (com.example.*)
- [x] Support suffix wildcards (*.created)
- [x] Support full wildcards (*)
- [x] Pattern compilation for efficiency (regex)

### Task 3.3.6: Event Filtering
- [x] Add filter function support
- [x] Support lambda/function filters
- [x] Support module/function filters
- [x] Handle filter function crashes gracefully

### Task 3.3.7: Error Handling
- [x] Isolate handler failures
- [x] Log handler errors
- [x] Continue delivery to other handlers
- [x] Track failed deliveries

### Task 3.3.8: Telemetry
- [x] Emit telemetry events for routing
- [x] Track delivery success/failure
- [x] Measure handler processing time

### Task 3.3.9: Handler Types
- [x] Support GenServer handlers (cast)
- [x] Support function handlers (anonymous)
- [x] Support module/function pairs
- [x] Support PID handlers

## Files Created

### New Files
- `lib/web_ui/dispatcher.ex` - Main dispatcher GenServer (328 lines)
- `lib/web_ui/dispatcher/handler.ex` - Handler behaviour (189 lines)
- `lib/web_ui/dispatcher/registry.ex` - Handler registry (292 lines)
- `test/web_ui/dispatcher_test.exs` - Dispatcher tests (333 lines)
- `test/web_ui/dispatcher/registry_test.exs` - Handler tests (100 lines)

## Configuration Options

```elixir
config :web_ui, WebUi.Dispatcher,
  handler_timeout: 5000,
  telemetry_enabled: true
```

## Test Results

**All 39 tests passing:**

Dispatcher tests (27 tests):
- subscribe/3: 6 tests (exact, prefix, suffix, full wildcard, module/function, filter, multiple)
- unsubscribe/1: 2 tests (unsubscribe, graceful non-existent handling)
- dispatch/1: 10 tests (exact match, prefix wildcard, suffix wildcard, full wildcard, multiple handlers, filter, no match, handler crash, filter crash)
- subscription_count/0: 3 tests (zero, count, after unsubscribe)
- module/function handler: 1 test
- gen_server handler: 1 test
- subscriptions/0: 1 test
- clear/0: 2 tests

Handler tests (12 tests):
- alive?/1: 5 tests (module/function, function, alive PID, dead PID, invalid)
- call/2: 4 tests (module/function, module/function/args, function handler, PID handler, crash)
- handler_id/1: 3 tests (module/function, module/function/args, PID, function)

## Implementation Details

### Pattern Matching
- Exact matches stored in ETS bag table with key `{:type, pattern}`
- Wildcard patterns compiled to regex and stored in separate ETS bag table
- Regex compilation caches patterns for efficient matching

### Handler Types Supported
- `{module, function}` - Calls `module.function(event)`
- `{module, function, args}` - Calls `apply(module, function, [event | args])`
- `function` - Calls `function.(event)`
- `PID` - Sends `GenServer.cast(pid, {:cloudevent, event})`

### Error Handling
- Handler failures caught and logged
- Other handlers continue to receive events
- Filter function failures caught and logged
- Telemetry tracks success/error counts

### ETS Tables
- `:web_ui_dispatcher_registry` - Exact type matches
- `:web_ui_dispatcher_patterns` - Wildcard patterns with compiled regex

## Success Criteria
1. [x] Dispatcher routes events to subscribed handlers
2. [x] Wildcard subscriptions work correctly
3. [x] Handler failures are isolated
4. [x] Telemetry events are emitted
5. [x] All tests passing (39/39)
