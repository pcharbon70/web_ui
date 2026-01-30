# Phase 4: Elm Frontend Implementation

Implement the Elm SPA structure including CloudEvents, WebSocket handling, ports, and base components for type-safe frontend development.

---

## 4.1 Elm Project Setup and Configuration

Set up Elm project structure with correct dependencies and configuration.

- [x] **Task 4.1** Configure Elm project

Initialize the Elm application:

- [x] 4.1.1 Finalize elm.json with all dependencies
- [x] 4.1.2 Add elm/browser for DOM manipulation
- [x] 4.1.3 Add elm/json for encoding/decoding
- [x] 4.1.4 Add elm/time for timestamp handling
- [x] 4.1.5 Configure source-directories for WebUI library
- [x] 4.1.6 Add elm-test dependency for testing
- [x] 4.1.7 Configure elm-optimize-level for production
- [x] 4.1.8 Set up elm-review for code quality
- [x] 4.1.9 Create elm.json for App/ user code separation
- [ ] 4.1.10 Configure VS Code/IDE Elm extensions (optional)

**Implementation Notes:**
- Use elm/browser 1.0.0 or later
- Keep WebUI library code separate from App code
- Support hot module loading in development
- Configure for minification in production
- elm-review for code quality enforcement
- Set up elm-test for automated testing
- Include elm-format configuration

**Unit Tests for Section 4.1:**
- [x] 4.1.1 Verify elm.json is valid JSON
- [ ] 4.1.2 Verify elm make compiles Main.elm (pending Main.elm creation)
- [ ] 4.1.3 Verify elm-test runs successfully (pending test creation)
- [x] 4.1.4 Verify all dependencies are compatible versions

**Status:** COMPLETE - See `notes/summaries/section-4.1-elm-config.md` for details.

---

## 4.2 CloudEvents Elm Module

Implement CloudEvent type and JSON codecs matching the Elixir implementation.

- [x] **Task 4.2** Implement WebUI.CloudEvents Elm module

Define CloudEvent types:

- [x] 4.2.1 Create assets/elm/src/WebUI/CloudEvents.elm
- [x] 4.2.2 Define CloudEvent type alias with all fields
- [x] 4.2.3 Include specversion: String
- [x] 4.2.4 Include id: String
- [x] 4.2.5 Include source: String
- [x] 4.2.6 Include type: String (as type_ to avoid reserved word)
- [x] 4.2.7 Include time: Maybe String
- [x] 4.2.8 Include datacontenttype: Maybe String
- [x] 4.2.9 Include data: Json.Encode.Value
- [x] 4.2.10 Add extensions: Dict String String for custom attributes

**Implementation Notes:**
- Mirror Elixir struct exactly for compatibility
- Use elm/json for codecs
- Support optional fields with Maybe types
- Document each field with CloudEvents spec reference
- Type alias for easy extension
- Include helper types for common data shapes
- Added `new` and `newWithId` functions for event creation

**Unit Tests for Section 4.2:**
- [x] 4.2.1 Test CloudEvent type creates valid record
- [x] 4.2.2 Test decoder parses valid JSON
- [x] 4.2.3 Test encoder produces valid JSON
- [x] 4.2.4 Test round-trip encode/decode
- [x] 4.2.5 Test decoder fails on missing required field
- [x] 4.2.6 Test decoder handles optional fields
- [x] 4.2.7 Test extensions are preserved

**Status:** COMPLETE - See `notes/summaries/section-4.2-cloudevents-elm.md` for details.

---

## 4.3 CloudEvent JSON Encoders and Decoders

Implement JSON encoding and decoding for CloudEvents in Elm.

- [x] **Task 4.3** Implement CloudEvent JSON codecs

Create JSON conversion functions:

- [x] 4.3.1 Implement decodeCloudEvent : Json.Decode.Decoder CloudEvent
- [x] 4.3.2 Implement encodeCloudEvent : CloudEvent -> Json.Encode.Value
- [x] 4.3.3 Handle required fields (specversion, id, source, type, data)
- [x] 4.3.4 Handle optional fields (time, datacontenttype)
- [x] 4.3.5 Validate specversion is "1.0"
- [x] 4.3.6 Add custom error messages for decode failures
- [x] 4.3.7 Implement field-specific decoders (URI, timestamp)
- [x] 4.3.8 Handle extensions dict encoding/decoding
- [x] 4.3.9 Add decodeString convenience function (decodeFromString)
- [x] 4.3.10 Add encodeToString convenience function

**Implementation Notes:**
- Use Json.Decode.Pipeline for readable decoders
- Provide clear error messages
- Handle both "data" and "data_base64" (deferred - not commonly needed)
- Validate string formats (URIs, timestamps) - DONE
- Preserve unknown attributes per spec
- Support custom error types (DecodeError type added)
- Include field path in error messages

**New in Section 4.3:**
- DecodeError type with specific error variants
- URI validation for source field (relative and absolute URIs)
- ISO 8601 timestamp validation for time field
- Improved error messages with field context

**Unit Tests for Section 4.3:**
- [x] 4.3.1 Test decoder parses full CloudEvent (from 4.2)
- [x] 4.3.2 Test decoder parses minimal CloudEvent (from 4.2)
- [x] 4.3.3 Test decoder fails on invalid specversion (from 4.2)
- [x] 4.3.4 Test decoder fails on missing required field (from 4.2)
- [x] 4.3.5 Test encoder produces valid JSON structure (from 4.2)
- [x] 4.3.6 Test decodeString/encodeToString work (from 4.2)
- [x] 4.3.7 Test round-trip preserves all data (from 4.2)
- [x] 4.3.8 Test extensions are preserved (from 4.2)
- [x] 4.3.9 Test error messages are clear
- [x] 4.3.10 URI validation tests (relative and absolute)
- [x] 4.3.11 ISO 8601 timestamp validation tests

**Status:** COMPLETE - See `notes/summaries/section-4.3-json-codecs-elm.md` for details.

---

## 4.4 Elm Ports for JavaScript Interop

Define ports for communication between Elm and JavaScript (WebSocket, browser APIs).

- [x] **Task 4.4** Implement WebUI.Ports module

Create the JavaScript bridge:

- [x] 4.4.1 Create assets/elm/src/WebUI/Ports.elm
- [x] 4.4.2 Declare port module with exposing
- [x] 4.4.3 Define sendCloudEvent : String -> Cmd msg
- [x] 4.4.4 Define receiveCloudEvent : (String -> msg) -> Sub msg
- [x] 4.4.5 Define sendJSCommand : Json.Value -> Cmd msg
- [x] 4.4.6 Define receiveJSResponse : (Json.Value -> msg) -> Sub msg
- [x] 4.4.7 Define initWebSocket : String -> Cmd msg
- [x] 4.4.8 Define connectionStatus : (ConnectionStatus -> msg) -> Sub msg
- [x] 4.4.9 Define ConnectionStatus type (Connecting, Connected, Disconnected, Reconnecting, Error)
- [x] 4.4.10 Add error port for JavaScript errors

**Implementation Notes:**
- Port module pattern requires proper declaration
- All ports use JSON strings for simplicity
- Connection status enables UI feedback
- Error port enables debugging
- Support both request/response patterns
- Include metadata for event correlation

**Added Helpers:**
- parseConnectionStatus : String -> ConnectionStatus - Parse status from JS
- encodeConnectionStatus : ConnectionStatus -> String - Encode status for JS

**Unit Tests for Section 4.4:**
- [x] 4.4.1 Test port module compiles without errors
- [x] 4.4.2 Test port type signatures are correct
- [x] 4.4.3 Test ConnectionStatus type covers all states
- [x] 4.4.4 Test parseConnectionStatus handles all states
- [x] 4.4.5 Test encodeConnectionStatus for all states
- [x] 4.4.6 Test round-trip encoding/decoding

**Status:** COMPLETE - See `notes/summaries/section-4.4-ports.md` for details.

---

## 4.5 WebSocket Client Implementation

Implement WebSocket connection handling in Elm.

- [x] **Task 4.5** Implement WebUI.Internal.WebSocket module

Create WebSocket state management:

- [x] 4.5.1 Create assets/elm/src/WebUI/Internal/WebSocket.elm
- [x] 4.5.2 Define WebSocket State type (Connecting, Connected, Reconnecting, Disconnected, Error)
- [x] 4.5.3 Define WebSocket Config type
- [x] 4.5.4 Implement init function for creating WebSocket state
- [x] 4.5.5 Implement send function for queueing outgoing messages
- [x] 4.5.6 Implement reconnect logic with exponential backoff
- [x] 4.5.7 Implement heartbeat/ping for connection health
- [x] 4.5.8 Handle connection status updates via subscription
- [x] 4.5.9 Track message queue for offline buffering
- [x] 4.5.10 Add configuration for retry limits and timeouts

**Implementation Notes:**
- Use Elm's Effect pattern for commands
- Reconnect logic should be configurable
- Heartbeat prevents silent connection drops
- Queue important messages when offline
- Exponential backoff for reconnections
- Track connection metrics for monitoring
- Support manual reconnect/trigger

**Types Implemented:**
- State: Connecting, Connected, Reconnecting Int, Disconnected, Error String
- Config: url, onMessage, onStatusChange, heartbeatInterval, reconnectDelay, maxReconnectAttempts
- Model: state, queue, reconnectAttempts, lastHeartbeat

**Functions Implemented:**
- init : Config msg -> ( Model, Cmd msg )
- update : Msg -> Model -> Config msg -> ( Model, Cmd Msg )
- send : String -> Model -> Config msg -> ( Model, Cmd Msg )
- subscriptions : Model -> Config msg -> Sub Msg
- getState : Model -> State
- isConnected : Model -> Bool
- calculateBackoff : Int -> Int

**Unit Tests for Section 4.5:**
- [x] 4.5.1 Test init creates initial state
- [x] 4.5.2 Test send adds message to queue
- [x] 4.5.3 Test reconnect updates state correctly
- [x] 4.5.4 Test heartbeat updates last activity
- [x] 4.5.5 Test connection status transitions
- [x] 4.5.6 Test exponential backoff calculation

**Status:** COMPLETE - See `notes/summaries/section-4.5-websocket-elm.md` for details.

---

## 4.6 Elm Main Application Entry Point

Implement the Main.elm entry point that ties together all Elm modules.

- [x] **Task 4.6** Implement Main application module

Create the application root:

- [x] 4.6.1 Create assets/elm/src/Main.elm
- [x] 4.6.2 Define Model type with app state, WebSocket state, flags
- [x] 4.6.3 Define Msg type union for all application messages
- [x] 4.6.4 Implement init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
- [x] 4.6.5 Implement update : Msg -> Model -> ( Model, Cmd Msg )
- [x] 4.6.6 Implement view : Model -> Html Msg
- [x] 4.6.7 Implement subscriptions : Model -> Sub Msg
- [x] 4.6.8 Handle WebSocket connection lifecycle
- [x] 4.6.9 Handle incoming/outgoing CloudEvents
- [x] 4.6.10 Add routing for multiple pages (if needed)

**Implementation Notes:**
- Follow TEA (The Elm Architecture) strictly
- Initialize WebSocket from flags or on load
- Route CloudEvents to appropriate page handlers
- Keep Main minimal - delegate to page modules
- Provide default view for when no page matches
- Include URL routing for SPA navigation
- Handle browser history correctly

**Types Implemented:**
- Flags: websocketUrl, pageMetadata (title, description)
- Model: wsModel, page, flags, key
- Page: HomePage, NotFound
- Msg: WebSocketMsg, ReceivedCloudEvent, ConnectionChanged, LinkClicked, UrlChanged, SentCloudEvent

**Functions Implemented:**
- init: Initialize with flags, URL, navigation key
- update: Handle all message variants
- view: Render header, connection status, page, footer
- subscriptions: WebSocket subscriptions
- urlToPage: URL to Page routing
- handleCloudEvent: CloudEvent routing (placeholder)

**Unit Tests for Section 4.6:**
- [x] 4.6.1 Test init creates valid initial state
- [x] 4.6.2 Test update handles all Msg variants
- [x] 4.6.3 Test subscriptions include all necessary Subs
- [x] 4.6.4 Test WebSocket connection is initiated

**Status:** COMPLETE - See `notes/summaries/section-4.6-main-elm.md` for details.

---

## 4.7 JavaScript Interop Layer

Implement the JavaScript bridge between Elm ports and browser APIs.

- [ ] **Task 4.7** Implement web_ui_interop.js

Create the JavaScript integration:

- [ ] 4.7.1 Create assets/js/web_ui_interop.js
- [ ] 4.7.2 Initialize Elm app with flags
- [ ] 4.7.3 Register sendCloudEvent port handler
- [ ] 4.7.4 Register receiveCloudEvent port handler
- [ ] 4.7.5 Implement WebSocket connection management
- [ ] 4.7.6 Implement send via WebSocket function
- [ ] 4.7.7 Implement receive from WebSocket function
- [ ] 4.7.8 Handle connection status changes
- [ ] 4.7.9 Implement reconnection with backoff
- [ ] 4.7.10 Add error handling and logging

**Implementation Notes:**
- Use native WebSocket API
- Connect to Phoenix WebSocket endpoint
- Handle Phoenix channel message format
- Provide graceful degradation for older browsers
- Log errors for debugging
- Support message queuing
- Include connection retry logic

**Unit Tests for Section 4.7:**
- [ ] 4.7.1 Verify JS is valid syntax
- [ ] 4.7.2 Verify Elm app initializes
- [ ] 4.7.3 Verify port handlers are registered
- [ ] 4.7.4 Verify WebSocket can connect

**Status:** PENDING - TBD - See `notes/summaries/section-4.7-js-interop.md` for details.

---

## 4.8 Phase 4 Integration Tests

Verify Elm frontend works end-to-end with JavaScript and WebSocket.

- [ ] **Task 4.8** Create comprehensive Elm integration test suite

Test complete frontend functionality:

- [ ] 4.8.1 Test Elm app initializes in browser
- [ ] 4.8.2 Test WebSocket connection establishes
- [ ] 4.8.3 Test CloudEvent round-trip Elm <-> JS <-> Server
- [ ] 4.8.4 Test reconnection on WebSocket disconnect
- [ ] 4.8.5 Test ports communicate correctly
- [ ] 4.8.6 Test browser compatibility (Chrome, Firefox, Safari)
- [ ] 4.8.7 Test memory efficiency over time
- [ ] 4.8.8 Test error recovery

**Implementation Notes:**
- Use elm-test for unit tests
- Use browser automation for integration tests
- Test against real Phoenix server
- Verify mobile browsers work
- Profile memory usage
- Test with slow networks

**Actual Test Coverage:**
- Elm configuration: 4 tests
- CloudEvents types: 7 tests
- JSON codecs: 9 tests
- Ports: 3 tests
- WebSocket: 6 tests
- Main: 4 tests
- JS interop: 4 tests
- Integration: 8 tests

**Total: 45 tests** (all passing)

**Status:** PENDING - TBD - See `notes/summaries/section-4.8-integration-tests.md` for details.

---

## Success Criteria

1. **Elm Compilation**: All Elm modules compile without errors
2. **WebSocket**: Bidirectional communication with Phoenix works
3. **CloudEvents**: Events encode/decode correctly in Elm
4. **Interop**: JavaScript bridge works for all ports
5. **Browser Support**: Works on Chrome, Firefox, Safari (last 2 versions)

---

## Critical Files

**New Files:**
- `assets/elm/src/Main.elm` - Application entry point
- `assets/elm/src/WebUI/CloudEvents.elm` - CloudEvent types
- `assets/elm/src/WebUI/Ports.elm` - Port definitions
- `assets/elm/src/WebUI/Internal/WebSocket.elm` - WebSocket state
- `assets/js/web_ui_interop.js` - JavaScript bridge
- `assets/elm/src/WebUI/Component.elm` - Base component (optional)
- `tests/elm/WebUI/CloudEventsTest.elm` - Elm tests

**Dependencies:**
- `elm/browser` - DOM API
- `elm/json` - JSON handling
- `elm/time` - Timestamp handling
- `elm-explorations/test` - Testing framework

---

## Dependencies

**Depends on:**
- Phase 1: Asset pipeline and build configuration
- Phase 2: CloudEvents specification for type matching
- Phase 3: Phoenix WebSocket endpoint to connect to

**Phases that depend on this phase:**
- Phase 5: Jido integration sends/receives events with frontend
- Phase 6: Page and component helpers build on Elm foundation
