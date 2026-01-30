port module WebUI.Ports exposing
    ( ConnectionStatus(..)
    , connectionStatus
    , initWebSocket
    , receiveCloudEvent
    , receiveJSError
    , receiveJSResponse
    , sendCloudEvent
    , sendJSCommand
    )

{-| Ports for JavaScript interoperability in WebUI.

This module defines all ports for communication between Elm and JavaScript.
Ports are the only way for Elm to communicate with the outside world.

# CloudEvent Ports

Send and receive CloudEvents as JSON strings.

@docs sendCloudEvent, receiveCloudEvent

# Command/Response Ports

Send commands to JavaScript and receive responses.

@docs sendJSCommand, receiveJSResponse

# WebSocket Ports

Initialize WebSocket connections and receive status updates.

@docs initWebSocket, connectionStatus, ConnectionStatus

# Error Port

Receive JavaScript errors.

@docs receiveJSError

-}

import Json.Encode exposing (Value)


{-| Connection status for WebSocket connections.

This type represents the current state of the WebSocket connection,
allowing the UI to display appropriate feedback to the user.

-}
type ConnectionStatus
    = Connecting
    | Connected
    | Disconnected
    | Reconnecting
    | Error String


{-| Send a CloudEvent to JavaScript as a JSON string.

This port sends a CloudEvent (serialized to JSON) to JavaScript,
which will typically forward it to a WebSocket or handle it
appropriately.

Example:

    eventJson =
        CloudEvents.encodeToString event

    Cmd.map GotCloudEventSent <|
        sendCloudEvent eventJson

The JavaScript side should subscribe to this port:

    app.ports.sendCloudEvent.subscribe(function(jsonString) {
        // Handle the CloudEvent JSON
        const event = JSON.parse(jsonString);
        // Send to WebSocket or handle otherwise
    });

-}
port sendCloudEvent : String -> Cmd msg


{-| Receive a CloudEvent from JavaScript as a JSON string.

This port receives CloudEvents from JavaScript, typically from
a WebSocket message or other external source.

Example:

    type Msg
        = GotCloudEvent String

    subscriptions model =
        receiveCloudEvent GotCloudEvent

The JavaScript side should send to this port:

    app.ports.receiveCloudEvent.send(jsonString);

-}
port receiveCloudEvent : (String -> msg) -> Sub msg


{-| Send a command to JavaScript as a JSON value.

This port sends arbitrary commands to JavaScript, allowing
the Elm app to trigger JavaScript-side functionality.

Example:

    command =
        Json.Encode.object
            [ ( "command", Json.Encode.string "localStorage" )
            , ( "action", Json.Encode.string "get" )
            , ( "key", Json.Encode.string "username" )
            ]

    Cmd.map GotJSResponse <|
        sendJSCommand command

The JavaScript side should subscribe to this port:

    app.ports.sendJSCommand.subscribe(function(command) {
        // Handle the command
        switch(command.command) {
            case "localStorage":
                // Handle localStorage operations
                break;
            // ... other commands
        }
    });

-}
port sendJSCommand : Value -> Cmd msg


{-| Receive a response from JavaScript as a JSON value.

This port receives responses to commands sent via `sendJSCommand`.

Example:

    type Msg
        = GotJSResponse Json.Encode.Value

    subscriptions model =
        receiveJSResponse GotJSResponse

The JavaScript side should send to this port:

    app.ports.receiveJSResponse.send(responseJson);

-}
port receiveJSResponse : (Value -> msg) -> Sub msg


{-| Initialize a WebSocket connection.

Provide the WebSocket URL to connect to. The connection status
will be updated through the `connectionStatus` port.

Example:

    Cmd.map GotConnectionStatus <|
        initWebSocket "ws://localhost:4000/socket"

The JavaScript side should subscribe to this port:

    app.ports.initWebSocket.subscribe(function(url) {
        // Initialize WebSocket connection
        socket = new WebSocket(url);
        // Set up event handlers and send status updates
    });

-}
port initWebSocket : String -> Cmd msg


{-| Receive WebSocket connection status updates.

This port receives updates about the WebSocket connection state,
allowing the UI to display connection status to the user.

The status is encoded as a string with the following format:
  - "Connecting" - Connection is being established
  - "Connected" - Connection is active
  - "Disconnected" - Connection is closed
  - "Reconnecting" - Attempting to reconnect
  - "Error:message" - Connection failed with error message

Example:

    type Msg
        = GotConnectionStatus ConnectionStatus

    subscriptions model =
        Sub.map GotConnectionStatus <|
            connectionStatus parseConnectionStatus

    parseConnectionStatus : String -> ConnectionStatus
    parseConnectionStatus status =
        case status of
            "Connecting" ->
                Connecting

            "Connected" ->
                Connected

            "Disconnected" ->
                Disconnected

            "Reconnecting" ->
                Reconnecting

            _ ->
                case String.split ":" status of
                    "Error" :: message :: [] ->
                        Error (String.join ":" message)

                    _ ->
                        Error "Unknown connection status"

The JavaScript side should send to this port:

    app.ports.connectionStatus.send("Connected");
    app.ports.connectionStatus.send("Error:Connection failed");

-}
port connectionStatus : (String -> msg) -> Sub msg


{-| Receive JavaScript errors.

This port receives error messages from JavaScript, allowing
the Elm app to log or display them to the user.

Example:

    type Msg
        = GotJSError String

    subscriptions model =
        receiveJSError GotJSError

The JavaScript side should send to this port:

    app.ports.receiveJSError.send(errorMessage);

-}
port receiveJSError : (String -> msg) -> Sub msg


{-| Helper to decode a connection status string into a ConnectionStatus.

This helper function parses the connection status string received
from JavaScript into the ConnectionStatus type.

-}
parseConnectionStatus : String -> ConnectionStatus
parseConnectionStatus status =
    case status of
        "Connecting" ->
            Connecting

        "Connected" ->
            Connected

        "Disconnected" ->
            Disconnected

        "Reconnecting" ->
            Reconnecting

        _ ->
            if String.startsWith "Error:" status then
                Error (String.drop 6 status)

            else
                Error status


{-| Helper to encode a ConnectionStatus to a string.

This helper function encodes a ConnectionStatus into the string
format expected by the JavaScript side.

-}
encodeConnectionStatus : ConnectionStatus -> String
encodeConnectionStatus status =
    case status of
        Connecting ->
            "Connecting"

        Connected ->
            "Connected"

        Disconnected ->
            "Disconnected"

        Reconnecting ->
            "Reconnecting"

        Error message ->
            "Error:" ++ message
