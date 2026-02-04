# Section 5.1 - WebUI.Agent Behaviour and Helpers

**Feature Branch:** `feature/section-5.1-agent-behaviour`
**Created:** 2025-01-31
**Status:** COMPLETED

## Overview

Implement the WebUI.Agent behaviour and helper functions for Jido agents that work with WebUI. This enables server-side business logic and state management through autonomous agents that respond to frontend events.

## Requirements from Phase 5 Plan

### Task 5.1: Implement WebUI.Agent behaviour

- [x] 5.1.1 Create lib/web_ui/agent.ex
- [x] 5.1.2 Define behaviour with handle_cloud_event/2 callback
- [x] 5.1.3 Define optional callbacks (init, terminate, child_spec)
- [x] 5.1.4 Implement use WebUI.Agent macro
- [x] 5.1.5 Auto-subscribe agent to event types on startup
- [x] 5.1.6 Provide send_event/2 for emitting events
- [x] 5.1.7 Provide reply/2 for responding to events
- [x] 5.1.8 Add event filtering support
- [x] 5.1.9 Include telemetry hooks
- [x] 5.1.10 Support both GenServer and Agent patterns

## Implementation Notes

- Behaviour should be optional (Jido dependency is optional)
- Allow agents to subscribe by type pattern or source pattern
- Provide callbacks for event lifecycle
- Include error recovery mechanisms
- Support correlation IDs for request/response tracking
- Include event transformation hooks
- Allow subscription to multiple event patterns
- Provide event history for debugging

## Unit Tests (18 tests passing)

- [x] 5.1.1 Test use macro adds required callbacks
- [x] 5.1.2 Test handle_cloud_event/2 is invoked
- [x] 5.1.3 Test send_event/2 emits to dispatcher
- [x] 5.1.4 Test reply/2 sends response
- [x] 5.1.5 Test agent subscribes to event types
- [x] 5.1.6 Test optional callbacks work
- [x] 5.1.7 Test correlation IDs are tracked
- [x] 5.1.8 Test event filtering works
- [x] Additional: test source generation
- [x] Additional: test child_spec customization

## Dependencies

**Depends on:**
- Phase 1: Application supervision tree
- Phase 2: CloudEvents for message format
- Phase 3: Event dispatcher for routing
- Phase 4: Elm frontend for event sources

**Optional Dependency:**
- `{:jido, "~> 1.2", optional: true}` - Agent framework

## Files to Create

1. `lib/web_ui/agent.ex` - Main Agent behaviour and helpers
2. `test/web_ui/agent_test.exs` - Unit tests for Agent behaviour

## Files to Modify

1. `lib/web_ui/application.ex` - Add Agent supervisor to supervision tree
2. `mix.exs` - Ensure jido dependency is optional

## Design Decisions

### Agent Behaviour Contract

The `WebUI.Agent` behaviour defines:

**Required Callbacks:**
- `handle_cloud_event(event, state)` - Handle incoming CloudEvents

**Optional Callbacks:**
- `init(opts)` - Initialize agent state
- `terminate(reason, state)` - Cleanup on termination
- `child_spec(opts)` - Customize child spec for supervision

### Subscription Patterns

Agents can subscribe to events by:
- Type pattern: `"com.example.*"`
- Source pattern: `"/my/source/*"`
- Full wildcard: `"*"`

### Correlation IDs

For request/response tracking:
- Incoming events with `correlationid` extension
- `reply/2` preserves correlation ID
- `send_event/2` can generate new correlation ID

### Telemetry Events

- `[:web_ui, :agent, :event_sent]` - Event sent

## Status Log

- **2025-01-31**: Branch created, planning started
- **2025-01-31**: Implementation complete - all 18 tests passing
