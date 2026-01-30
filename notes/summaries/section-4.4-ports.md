# Section 4.4: Elm Ports for JavaScript Interop - Summary

**Branch:** `feature/phase-4.4-ports`
**Date:** 2026-01-29
**Status:** Complete

## Overview

Implemented the WebUI.Ports module for communication between Elm and JavaScript. Ports are the only mechanism in Elm for interop with JavaScript, enabling WebSocket connections, browser API access, and other external functionality.

## Ports Implemented

### CloudEvent Ports

1. **sendCloudEvent : String -> Cmd msg**
   - Sends CloudEvent JSON to JavaScript
   - Typically forwarded to WebSocket

2. **receiveCloudEvent : (String -> msg) -> Sub msg**
   - Receives CloudEvent JSON from JavaScript
   - Typically from WebSocket messages

### Command/Response Ports

3. **sendJSCommand : Json.Value -> Cmd msg**
   - Sends commands to JavaScript
   - For triggering browser APIs, localStorage, etc.

4. **receiveJSResponse : (Json.Value -> msg) -> Sub msg**
   - Receives responses from JavaScript
   - Handles results of JS commands

### WebSocket Ports

5. **initWebSocket : String -> Cmd msg**
   - Initializes WebSocket connection
   - Takes WebSocket URL as parameter

6. **connectionStatus : (String -> msg) -> Sub msg**
   - Receives connection status updates
   - Enables UI feedback on connection state

### Error Port

7. **receiveJSError : (String -> msg) -> Sub msg**
   - Receives JavaScript errors
   - Enables error logging/display

## Types Defined

### ConnectionStatus

```elm
type ConnectionStatus
    = Connecting
    | Connected
    | Disconnected
    | Reconnecting
    | Error String
```

Five states covering the WebSocket connection lifecycle.

## Helper Functions

### parseConnectionStatus

Parses a connection status string from JavaScript into ConnectionStatus:

```elm
parseConnectionStatus : String -> ConnectionStatus
```

Handles:
- "Connecting" → Connecting
- "Connected" → Connected
- "Disconnected" → Disconnected
- "Reconnecting" → Reconnecting
- "Error:message" → Error message

### encodeConnectionStatus

Encodes ConnectionStatus to string for JavaScript:

```elm
encodeConnectionStatus : ConnectionStatus -> String
```

## Files Created

1. `assets/elm/src/WebUI/Ports.elm` - Ports module (280 lines)
2. `assets/elm/tests/WebUI/PortsTest.elm` - Tests (225 lines)

## Files Modified

1. `notes/planning/poc/phase-4-elm-frontend.md` - Marked tasks complete

## Tests (17 total)

**ConnectionStatus Type (1 test):**
- 4.4.3 - ConnectionStatus type covers all states

**parseConnectionStatus (7 tests):**
- Parses Connecting status
- Parses Connected status
- Parses Disconnected status
- Parses Reconnecting status
- Parses Error status with message
- Parses Error status with colon in message
- Treats unknown status as Error

**encodeConnectionStatus (5 tests):**
- Encodes Connecting status
- Encodes Connected status
- Encodes Disconnected status
- Encodes Reconnecting status
- Encodes Error status with message

**Round-trip (5 tests):**
- Round-trips Connecting status
- Round-trips Connected status
- Round-trips Disconnected status
- Round-trips Reconnecting status
- Round-trips Error status

## JavaScript Integration

The JavaScript side must implement corresponding handlers:

```javascript
// Initialize Elm app
var app = Elm.Main.init({ node: document.getElementById('app') });

// WebSocket initialization
app.ports.initWebSocket.subscribe(function(url) {
    socket = new WebSocket(url);
    socket.onmessage = function(event) {
        app.ports.receiveCloudEvent.send(event.data);
    };
    socket.onopen = function() {
        app.ports.connectionStatus.send('Connected');
    };
    socket.onclose = function() {
        app.ports.connectionStatus.send('Disconnected');
    };
    socket.onerror = function(error) {
        app.ports.connectionStatus.send('Error:' + error.message);
    };
});

// Send CloudEvent to WebSocket
app.ports.sendCloudEvent.subscribe(function(jsonString) {
    if (socket && socket.readyState === WebSocket.OPEN) {
        socket.send(jsonString);
    }
});

// Handle JS commands
app.ports.sendJSCommand.subscribe(function(command) {
    // Handle command based on structure
    var response = handleCommand(command);
    app.ports.receiveJSResponse.send(response);
});
```

## Usage Example in Elm

```elm
import WebUI.Ports as Ports
import Json.Encode as Encode

type Msg
    = GotCloudEvent String
    | GotConnectionStatus Ports.ConnectionStatus
    | GotJSResponse Encode.Value
    | GotJSError String

-- Send a CloudEvent
sendEvent : String -> Cmd Msg
sendEvent json =
    Ports.sendCloudEvent json

-- Initialize WebSocket
initSocket : String -> Cmd Msg
initSocket url =
    Cmd.map GotConnectionStatus <|
        Ports.initWebSocket url

-- Subscriptions
subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.receiveCloudEvent GotCloudEvent
        , Sub.map GotConnectionStatus <|
            Ports.connectionStatus Ports.parseConnectionStatus
        , Ports.receiveJSResponse GotJSResponse
        , Ports.receiveJSError GotJSError
        ]
```

## Breaking Changes

None. This is a new module.

## Dependencies

- `elm/core` - Basics, String, Cmd, Sub
- `elm/json` - Json.Encode

## Next Steps

Section 4.5: WebSocket Client Implementation
- Create WebUI.Internal.WebSocket module
- Implement WebSocket state management
- Add reconnect logic with exponential backoff
- Implement heartbeat/ping for connection health

## Notes

- Ports are the boundary between Elm and JavaScript
- All data crossing ports must be JSON-serializable
- Port names must match exactly between Elm and JavaScript
- The helper functions make ConnectionStatus handling ergonomic
