# Phase 3.2: WebSocket Channel for CloudEvents

**Feature Branch:** `feature/phase-3.2-channel`

**Status:** COMPLETE

**Date:** 2025-01-27

**Goal:** Implement Phoenix Channel for bidirectional CloudEvents communication over WebSocket with proper authorization, validation, and broadcasting.

## Implementation Summary

The EventChannel has been extracted from `lib/web_ui/endpoint.ex` into a dedicated module with comprehensive CloudEvent handling, authorization support, and broadcasting capabilities.

## Implementation Tasks

### Task 3.2.1: Extract EventChannel to Separate Module
- [x] Create lib/web_ui/channels/event_channel.ex
- [x] Move existing EventChannel code to new module
- [x] Update endpoint.ex to reference new module
- [x] Add proper module documentation

### Task 3.2.2: Implement Authorization Callback
- [x] Add authorization behaviour/config
- [x] Implement configurable join authorization via `:authorize_join`
- [x] Add support for user-specific channels (user:<id>)
- [x] Add token-based authentication hooks (configurable callback)

### Task 3.2.3: Enhance CloudEvent Handling
- [x] Decode JSON CloudEvents from client messages
- [x] Validate CloudEvents with required field checks
- [x] Handle validation errors with proper responses
- [x] Support map payloads

### Task 3.2.4: Implement Heartbeat/Keepalive
- [x] Add `send_heartbeat/1` function for periodic heartbeat
- [x] Track last activity for connection monitoring (`:last_activity` assign)
- [x] Implement connection timeout detection (via Phoenix timeout)
- [x] Add configurable heartbeat interval (`:heartbeat_interval`)

### Task 3.2.5: Enhanced Broadcasting
- [x] Support broadcasting to specific rooms (`broadcast_cloudevent/2`)
- [x] Add selective broadcasting based on event type (via subscriptions)
- [x] Implement `broadcast_from` for exclusion of sender
- [x] Track event subscriptions (`:event_subscriptions` assign)

### Task 3.2.6: Channel-Specific Event Routing
- [x] Route events based on CloudEvent type
- [x] Support type-based subscriptions (`subscribe` message)
- [x] Add event filtering capabilities (unsubscribe)
- [x] Implement wildcard pattern matching

### Task 3.2.7: Disconnect Handling
- [x] Track client connections (assigns: room_id, joined_at, error_count)
- [x] Clean up resources on disconnect (terminate/2)
- [x] Log disconnect reasons

### Task 3.2.8: Error Handling
- [x] Handle malformed CloudEvents gracefully
- [x] Send error responses to clients (`push` error messages)
- [x] Log errors with context
- [x] Track error count (`:error_count` assign)

## Files Created

### New Files
- `lib/web_ui/channels/event_channel.ex` - Main channel implementation (397 lines)
- `test/web_ui/channels/event_channel_test.exs` - Channel tests (20 tests)

### Files Modified
- `lib/web_ui/endpoint.ex` - Removed EventChannel module (was lines 248-334, now removed)
- `test/web_ui/endpoint_test.exs` - Removed duplicate EventChannelTest module

## Configuration Options

```elixir
config :web_ui, WebUi.EventChannel,
  heartbeat_interval: 30_000,  # 30 seconds (default)
  authorize_join: {MyApp.Auth, :authorize_channel_join}  # Optional
```

## Test Results

All tests passing:
- 126 doctests
- 281 unit tests (including 20 new EventChannel tests)
- **Total: 407 tests, 0 failures**

### New Tests Added (20 tests)
- join/3 tests (3 tests)
- handle_in/3 for cloudevent (1 test)
- handle_in/3 for ping (2 tests)
- handle_in/3 for subscribe (4 tests)
- handle_in/3 for unsubscribe (4 tests)
- handle_in/3 for unknown messages (1 test)
- terminate/2 (2 tests)
- heartbeat_interval/0 (2 tests)
- broadcast_cloudevent/2 (1 test)
- send_heartbeat/1 (1 test)

## Success Criteria
1. [x] EventChannel in separate module
2. [x] Authorization works correctly
3. [x] CloudEvents are validated before processing
4. [x] Heartbeat keeps connections alive
5. [x] Broadcasting works to rooms and lobby
6. [x] Disconnects are handled gracefully
7. [x] All tests passing

## API Reference

### Join Topics
- `"events:lobby"` - Public lobby for all clients
- `"events:<room_id>"` - Private room for specific events
- `"events:user:<user_id>"` - User-specific channel (future)

### Client Messages
- `"cloudevent"` - Send a CloudEvent to the server
- `"ping"` - Ping the server (responds with `"pong"`)
- `"subscribe"` - Subscribe to specific event types
- `"unsubscribe"` - Unsubscribe from event types

### Server Messages
- `"cloudevent"` - A CloudEvent from another client or server
- `"pong"` - Response to a ping message
- `"heartbeat"` - Periodic heartbeat to keep connection alive
- `"error"` - Error response for invalid events

### Public Functions
- `join/3` - Authorize and handle channel joins
- `handle_in/3` - Handle incoming messages from clients
- `terminate/2` - Handle client disconnect
- `broadcast_cloudevent/2` - Broadcast CloudEvent to a room
- `broadcast_cloudevent_from/3` - Broadcast excluding sender
- `send_heartbeat/1` - Send heartbeat to a room
- `heartbeat_interval/0` - Get configured heartbeat interval
