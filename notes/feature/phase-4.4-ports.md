# Phase 4.4: Elm Ports for JavaScript Interop

**Branch:** `feature/phase-4.4-ports`
**Date:** 2026-01-29
**Status:** In Progress

## Overview

Implement the WebUI.Ports module for communication between Elm and JavaScript. Ports are the only way for Elm to communicate with JavaScript, enabling WebSocket connections, browser API access, and other JavaScript functionality.

## Ports to Implement

### CloudEvent Ports
- `sendCloudEvent : String -> Cmd msg` - Send CloudEvent JSON to JavaScript
- `receiveCloudEvent : (String -> msg) -> Sub msg` - Receive CloudEvent JSON from JavaScript

### Command/Response Ports
- `sendJSCommand : Json.Value -> Cmd msg` - Send command to JavaScript
- `receiveJSResponse : (Json.Value -> msg) -> Sub msg` - Receive response from JavaScript

### WebSocket Ports
- `initWebSocket : String -> Cmd msg` - Initialize WebSocket connection
- `connectionStatus : (ConnectionStatus -> msg) -> Sub msg` - Receive connection status updates

### Error Port
- `receiveJSError : (String -> msg) -> Sub msg` - Receive JavaScript errors

## Types to Define

### ConnectionStatus

```elm
type ConnectionStatus
    = Connecting
    | Connected
    | Disconnected
    | Reconnecting
    | Error String
```

## Implementation Plan

### Step 1: Create Ports Module

Create `assets/elm/src/WebUI/Ports.elm` with port module declaration.

### Step 2: Define ConnectionStatus Type

Add the ConnectionStatus type with all states.

### Step 3: Declare Ports

Use `port` keyword to declare all ports.

### Step 4: Document Usage

Add documentation for each port with examples.

### Step 5: Create JavaScript Side (Documentation)

Document the JavaScript implementation requirements.

## Files to Create

1. `assets/elm/src/WebUI/Ports.elm` - Main ports module
2. `notes/summaries/section-4.4-ports.md` - Summary

## Files to Modify

1. `notes/planning/poc/phase-4-elm-frontend.md` - Mark tasks complete

## JavaScript Implementation Notes

The JavaScript side must implement:

```javascript
// Send CloudEvent to Elm
app.ports.receiveCloudEvent.send(jsonString);

// Receive CloudEvent from Elm
app.ports.sendCloudEvent.subscribe(function(jsonString) {
    // Handle CloudEvent
});

// WebSocket connection status
app.ports.connectionStatus.send({
    tag: "Connected", // or "Connecting", "Disconnected", "Error"
    error: null // optional error message
});
```

## Success Criteria

- [x] Feature branch created
- [ ] Ports.elm module created
- [ ] ConnectionStatus type defined
- [ ] All 8 ports declared
- [ ] Module compiles without errors
- [ ] Documentation complete
- [ ] Planning document updated
- [ ] Summary written

## Notes

- Ports must have type signatures
- Port names must match between Elm and JavaScript
- ConnectionStatus uses a tagged union for clean state management
- All data is sent as JSON strings for simplicity

## Questions for Developer

None at this time. Proceeding with implementation.
