# Phase 4.5: WebSocket Client Implementation

**Branch:** `feature/phase-4.5-websocket`
**Date:** 2026-01-29
**Status:** In Progress

## Overview

Implement the WebUI.Internal.WebSocket module for WebSocket state management in Elm. This module handles the connection lifecycle, message queuing, reconnection logic, and heartbeat functionality.

## Types to Define

### State

```elm
type State
    = Connecting
    | Connected
    | Reconnecting Int
    | Disconnected
    | Error String
```

### Config

```elm
type alias Config msg =
    { url : String
    , onMessage : String -> msg
    , onStatusChange : State -> msg
    , heartbeatInterval : Int
    , reconnectDelay : Int
    , maxReconnectAttempts : Int
    }
```

### Model

```elm
type alias Model =
    { state : State
    , queue : List String
    , lastHeartbeat : Maybe Int
    , reconnectAttempts : Int
    }
```

## Implementation Plan

### Step 1: Create WebSocket Module

Create `assets/elm/src/WebUI/Internal/WebSocket.elm` with:
- State type
- Config type alias
- Model type alias

### Step 2: Implement Init

Create init function that:
- Takes configuration
- Returns initial model
- Returns initial commands

### Step 3: Implement Send

Create send function that:
- Queues messages when disconnected
- Sends immediately when connected
- Returns appropriate command

### Step 4: Implement Reconnect Logic

Create reconnect function with:
- Exponential backoff calculation
- Max retry limit checking
- State updates

### Step 5: Implement Heartbeat

Create heartbeat function for:
- Periodic ping messages
- Connection health monitoring
- Auto-reconnect on timeout

### Step 6: Create Update Function

Main update function that handles:
- Connection status changes
- Incoming messages
- Heartbeat ticks
- Reconnection triggers

## Files to Create

1. `assets/elm/src/WebUI/Internal/WebSocket.elm` - Main WebSocket module
2. `assets/elm/tests/WebUI/Internal/WebSocketTest.elm` - Tests
3. `notes/summaries/section-4.5-websocket-elm.md` - Summary

## Files to Modify

1. `notes/planning/poc/phase-4-elm-frontend.md` - Mark tasks complete

## Functions to Implement

### Core Functions
- `init : Config msg -> ( Model, Cmd msg )`
- `update : Msg -> Model -> Config msg -> ( Model, Cmd msg )`
- `send : String -> Model -> Config msg -> ( Model, Cmd msg )`
- `subscriptions : Model -> Config msg -> Sub msg`

### Internal Messages
- `Heartbeat` - Periodic heartbeat tick
- `ReceiveMessage` - Incoming message from ports
- `ConnectionStatusChanged` - Status update from ports
- `AttemptReconnect` - Trigger reconnection

### Helper Functions
- `calculateBackoff : Int -> Int` - Exponential backoff
- `shouldReconnect : Model -> Bool` - Check if should reconnect
- `isConnected : Model -> Bool` - Connection status check

## Success Criteria

- [x] Feature branch created
- [ ] WebSocket.elm module created
- [ ] State, Config, Model types defined
- [ ] init, update, send functions implemented
- [ ] Reconnect logic with exponential backoff
- [ ] Heartbeat functionality
- [ ] Message queuing for offline buffering
- [ ] All tests pass
- [ ] Planning document updated
- [ ] Summary written

## Notes

- The actual WebSocket connection is handled by JavaScript via ports
- This module manages the Elm-side state and logic
- Heartbeat messages are simple JSON pings
- Reconnect uses exponential backoff: 2^n * baseDelay
- Max retry limit prevents infinite reconnection loops

## Questions for Developer

None at this time. Proceeding with implementation.
