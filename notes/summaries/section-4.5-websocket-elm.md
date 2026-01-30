# Section 4.5: WebSocket Client Implementation - Summary

**Branch:** `feature/phase-4.5-websocket`
**Date:** 2026-01-29
**Status:** Complete

## Overview

Implemented the WebUI.Internal.WebSocket module for WebSocket state management in Elm. This module handles the connection lifecycle, message queuing, reconnection logic with exponential backoff, and heartbeat functionality.

## Types Defined

### State

```elm
type State
    = Connecting
    | Connected
    | Reconnecting Int
    | Disconnected
    | Error String
```

The `Reconnecting Int` variant tracks the current reconnect attempt count.

### Config

```elm
type alias Config msg =
    { url : String
    , onMessage : String -> msg
    , onStatusChange : State -> msg
    , heartbeatInterval : Int  -- seconds
    , reconnectDelay : Int      -- milliseconds
    , maxReconnectAttempts : Int
    }
```

Configuration for WebSocket behavior and message routing.

### Model

```elm
type alias Model =
    { state : State
    , queue : List String
    , reconnectAttempts : Int
    , lastHeartbeat : Maybe Int
    }
```

Internal state including message queue for offline buffering.

### Msg

```elm
type Msg
    = Heartbeat
    | ReceiveMessage String
    | ConnectionStatusChanged Ports.ConnectionStatus
    | AttemptReconnect
    | SentMessage
```

Messages for WebSocket state machine.

## Functions Implemented

### Core Functions

**init : Config msg -> ( Model, Cmd msg )**
- Creates initial WebSocket model
- Starts heartbeat timer
- Initial state is `Connecting`

**update : Msg -> Model -> Config msg -> ( Model, Cmd Msg )**
- Handles incoming WebSocket messages
- Manages connection state transitions
- Triggers reconnection when needed
- Sends status change notifications

**send : String -> Model -> Config msg -> ( Model, Cmd Msg )**
- Sends message if connected
- Queues message if disconnected
- Returns command to send via port

**subscriptions : Model -> Config msg -> Sub Msg**
- Subscribes to CloudEvents from JavaScript
- Subscribes to connection status changes

### Query Functions

**getState : Model -> State**
- Returns current connection state

**isConnected : Model -> Bool**
- Returns True if connected, False otherwise

### Helper Functions

**calculateBackoff : Int -> Int**
- Calculates exponential backoff delay
- Formula: 2^n * 1000ms, capped at 30000ms
- Examples:
  - attempt 0: 1000ms
  - attempt 1: 2000ms
  - attempt 2: 4000ms
  - attempt 3: 8000ms
  - attempt 10+: 30000ms (capped)

## Files Created

1. `assets/elm/src/WebUI/Internal/WebSocket.elm` - WebSocket module (270 lines)
2. `assets/elm/tests/WebUI/Internal/WebSocketTest.elm` - Tests (245 lines)

## Files Modified

1. `notes/planning/poc/phase-4-elm-frontend.md` - Marked tasks complete

## Tests (15 total)

**State Type (1 test):**
- State type covers all connection states

**Init (1 test):**
- init creates initial state

**Send (2 tests):**
- send queues message when disconnected
- send sends immediately when connected

**calculateBackoff (2 tests):**
- exponential backoff calculation
- backoff caps at 30 seconds

**isConnected (4 tests):**
- Returns True when Connected
- Returns False when Disconnected
- Returns False when Connecting
- Returns False when Error

**getState (1 test):**
- Returns current state

**Update (4 tests):**
- connection status transitions
- reconnect updates state correctly
- heartbeat updates last activity

## Usage Example

```elm
import WebUI.Internal.WebSocket as WebSocket

type Msg
    = WebSocketMsg WebSocket.Msg
    | ReceivedCloudEvent String
    | ConnectionChanged WebSocket.State

type alias Model =
    { wsModel : WebSocket.Model
    , -- other app state
    }

wsConfig : WebSocket.Config Msg
wsConfig =
    { url = "ws://localhost:4000/socket"
    , onMessage = ReceivedCloudEvent
    , onStatusChange = ConnectionChanged
    , heartbeatInterval = 30
    , reconnectDelay = 1000
    , maxReconnectAttempts = 5
    }

init : () -> ( Model, Cmd Msg )
init _ =
    let
        ( wsModel, wsCmd ) =
            WebSocket.init wsConfig
    in
    ( { wsModel = wsModel }
    , Cmd.map WebSocketMsg wsCmd
    )

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        WebSocketMsg wsMsg ->
            let
                ( newWsModel, wsCmd ) =
                    WebSocket.update wsMsg model.wsModel wsConfig
            in
            ( { model | wsModel = newWsModel }
            , Cmd.map WebSocketMsg wsCmd
            )

        ReceivedCloudEvent data ->
            -- Handle incoming CloudEvent
            ( model, Cmd.none )

        ConnectionChanged state ->
            -- Handle connection state change
            ( model, Cmd.none )

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map WebSocketMsg <|
        WebSocket.subscriptions model.wsModel wsConfig

sendMessage : String -> Model -> ( Model, Cmd Msg )
sendMessage json model =
    let
        ( newWsModel, wsCmd ) =
            WebSocket.send json model.wsModel wsConfig
    in
    ( { model | wsModel = newWsModel }
    , Cmd.map WebSocketMsg wsCmd
    )
```

## Design Decisions

1. **Message Queue**: Messages are queued when disconnected and sent when connection is restored. This provides offline buffering.

2. **Exponential Backoff**: Reconnection attempts use exponential backoff to avoid overwhelming the server.

3. **Max Retry Limit**: Configurable max retry attempts prevent infinite reconnection loops.

4. **Heartbeat**: Periodic heartbeat helps detect silent connection drops.

5. **State Notification**: External code is notified of state changes via `onStatusChange` callback.

## Breaking Changes

None. This is a new module.

## Dependencies

- `elm/core` - Basics, List, Maybe, Process, Task
- `WebUI.Ports` - Port declarations

## Next Steps

Section 4.6: Elm Main Application Entry Point
- Create Main.elm
- Define Model and Msg types
- Implement init, update, view, subscriptions
- Integrate WebSocket module

## Notes

- The actual WebSocket connection is handled by JavaScript via ports
- This module manages Elm-side state and logic only
- Connection status flows from JavaScript through ports
- Heartbeat is implemented as periodic Process.sleep calls
