module WebUI.Internal.WebSocket exposing
    ( Model
    , Msg(..)
    , State(..)
    , Config
    , init
    , update
    , send
    , subscriptions
    , getState
    , isConnected
    , calculateBackoff
    )

{-| WebSocket client state management for Elm.

This module handles the Elm-side state and logic for WebSocket connections.
The actual WebSocket connection is managed by JavaScript via ports.

# Types

@docs Model, Msg, State, Config

# Creation

@docs init

# Updates

@docs update, send

# Subscriptions

@docs subscriptions

# Queries

@docs getState, isConnected

# Helpers

@docs calculateBackoff

-}

import Process
import Task exposing (Task)
import WebUI.Ports as Ports



-- TYPES


{-| The WebSocket connection state.

-}
type State
    = Connecting
    | Connected
    | Reconnecting Int
    | Disconnected
    | Error String


{-| Configuration for the WebSocket client.

-}
type alias Config msg =
    { url : String
    , onMessage : String -> msg
    , onStatusChange : State -> msg
    , heartbeatInterval : Int
    , reconnectDelay : Int
    , maxReconnectAttempts : Int
    }


{-| The WebSocket model containing connection state and queued messages.

-}
type alias Model =
    { state : State
    , queue : List String
    , reconnectAttempts : Int
    , lastHeartbeat : Maybe Int
    }



-- MESSAGES


{-| Messages for WebSocket state management.

-}
type Msg
    = Heartbeat
    | ReceiveMessage String
    | ConnectionStatusChanged Ports.ConnectionStatus
    | AttemptReconnect
    | SentMessage



-- CREATION


{-| Initialize the WebSocket model.

Example:

    ( wsModel, wsCmd ) =
        WebSocket.init config

-}
init : Config msg -> ( Model, Cmd Msg )
init config =
    ( { state = Connecting
      , queue = []
      , reconnectAttempts = 0
      , lastHeartbeat = Nothing
      }
    , Task.perform (always Heartbeat) (Process.sleep (toFloat config.heartbeatInterval * 1000))
    )



-- UPDATE


{-| Update the WebSocket model.

Example:

    ( wsModel, wsCmd ) =
        WebSocket.update msg wsModel config

-}
update : Msg -> Model -> Config msg -> ( Model, Cmd Msg )
update msg model config =
    case msg of
        Heartbeat ->
            handleHeartbeat model config

        ReceiveMessage data ->
            handleReceiveMessage model config data

        ConnectionStatusChanged status ->
            handleConnectionStatusChanged model config status

        AttemptReconnect ->
            handleAttemptReconnect model config

        SentMessage ->
            ( model, Cmd.none )



-- HANDLERS


handleHeartbeat : Model -> Config msg -> ( Model, Cmd Msg )
handleHeartbeat model config =
    let
        heartbeatCmd =
            if isConnected model then
                Task.perform (always Heartbeat) (Process.sleep (toFloat config.heartbeatInterval * 1000))

            else
                Cmd.none
    in
    ( { model | lastHeartbeat = Just 0 }, heartbeatCmd )


handleReceiveMessage : Model -> Config msg -> String -> ( Model, Cmd Msg )
handleReceiveMessage model config data =
    ( model
    , Cmd.none
    )


handleConnectionStatusChanged : Model -> Config msg -> Ports.ConnectionStatus -> ( Model, Cmd Msg )
handleConnectionStatusChanged model config status =
    let
        newState =
            case status of
                Ports.Connecting ->
                    Connecting

                Ports.Connected ->
                    Connected

                Ports.Disconnected ->
                    Disconnected

                Ports.Reconnecting ->
                    Reconnecting model.reconnectAttempts

                Ports.Error message ->
                    Error message
    in
    ( { model | state = newState }
    , Cmd.none
    )


handleAttemptReconnect : Model -> Config msg -> ( Model, Cmd Msg )
handleAttemptReconnect model config =
    if model.reconnectAttempts >= config.maxReconnectAttempts then
        ( { model | state = Error "Max reconnect attempts reached" }
        , Cmd.none
        )

    else
        let
            -- Increment first, then use for both state and backoff
            newAttempts =
                model.reconnectAttempts + 1

            backoff =
                calculateBackoff model.reconnectAttempts

            newModel =
                { model
                    | state = Reconnecting newAttempts
                    , reconnectAttempts = newAttempts
                }
        in
        ( newModel
        , Task.perform (\() -> AttemptReconnect) (Process.sleep (toFloat backoff))
        )



-- SEND


{-| Send a message through the WebSocket.

If connected, sends immediately. If disconnected, queues for later.

Example:

    ( wsModel, wsCmd ) =
        WebSocket.send jsonMessage wsModel config

-}
send : String -> Model -> Config msg -> ( Model, Cmd Msg )
send data model config =
    if isConnected model then
        ( model, Ports.sendCloudEvent data )

    else
        ( { model | queue = model.queue ++ [ data ] }, Cmd.none )



-- SUBSCRIPTIONS


{-| Subscriptions for WebSocket messages.

Example:

    subscriptions =
        WebSocket.subscriptions model config

-}
subscriptions : Model -> Config msg -> Sub Msg
subscriptions model config =
    Sub.batch
        [ Ports.receiveCloudEvent ReceiveMessage
        , Sub.map ConnectionStatusChanged <|
            Ports.connectionStatus (always Ports.Connecting)
        ]



-- QUERIES


{-| Get the current connection state.

-}
getState : Model -> State
getState model =
    model.state


{-| Check if the WebSocket is connected.

-}
isConnected : Model -> Bool
isConnected model =
    case model.state of
        Connected ->
            True

        _ ->
            False



-- HELPERS


{-| Calculate exponential backoff delay in milliseconds.

Formula: 2^n * baseDelay, capped at 30 seconds

Examples:

    calculateBackoff 0    -- 1000
    calculateBackoff 1    -- 2000
    calculateBackoff 2    -- 4000
    calculateBackoff 3    -- 8000
    calculateBackoff 10   -- 30000 (capped)

-}
calculateBackoff : Int -> Int
calculateBackoff attempts =
    let
        baseDelay =
            1000

        maxDelay =
            30000

        exponential =
            Basics.min (2 ^ attempts) 30
    in
    Basics.min (exponential * baseDelay) maxDelay
