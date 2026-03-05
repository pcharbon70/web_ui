module MainTest exposing (suite)

import Expect
import Json.Encode as Encode
import Main exposing (..)
import Test exposing (..)
import Url
import WebUI.CloudEvents as CloudEvents
import WebUI.Internal.WebSocket as WebSocket
import WebUI.Ports as Ports


suite : Test
suite =
    describe "Main"
        [ describe "urlToPage"
            [ test "maps / to HomePage" <|
                \_ ->
                    let
                        url =
                            Url.Url Url.Https "example.com" Nothing "/" Nothing Nothing
                    in
                    case urlToPage url of
                        HomePage ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected HomePage"
            , test "maps /counter to CounterPage" <|
                \_ ->
                    let
                        url =
                            Url.Url Url.Https "example.com" Nothing "/counter" Nothing Nothing
                    in
                    case urlToPage url of
                        CounterPage ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected CounterPage"
            , test "maps unknown paths to NotFound" <|
                \_ ->
                    let
                        url =
                            Url.Url Url.Https "example.com" Nothing "/unknown" Nothing Nothing
                    in
                    case urlToPage url of
                        NotFound ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected NotFound"
            ]
        , describe "stateToString"
            [ test "renders connected state" <|
                \_ ->
                    Expect.equal "Connected" (stateToString WebSocket.Connected)
            , test "renders error state with message" <|
                \_ ->
                    Expect.equal "Error: test error" (stateToString (WebSocket.Error "test error"))
            ]
        , describe "command gating"
            [ test "does not queue counter commands while disconnected" <|
                \_ ->
                    let
                        model =
                            modelForState WebSocket.Disconnected

                        ( updated, _ ) =
                            update IncrementClicked model
                    in
                    Expect.equal [] updated.wsModel.queue
            , test "connected commands are not queued" <|
                \_ ->
                    let
                        model =
                            modelForState WebSocket.Connected

                        ( updated, _ ) =
                            update ResetClicked model
                    in
                    Expect.equal [] updated.wsModel.queue
            ]
        , describe "sync behavior"
            [ test "connected transition marks sync as pending and clears stale error" <|
                \_ ->
                    let
                        baseModel =
                            modelForState WebSocket.Disconnected

                        model =
                            { baseModel
                                | syncPending = False
                                , counterError = Just "old error"
                            }

                        ( updated, _ ) =
                            update (WebSocketMsg (WebSocket.ConnectionStatusChanged Ports.Connected)) model
                    in
                    Expect.all
                        [ \_ -> Expect.equal True updated.syncPending
                        , \_ -> Expect.equal Nothing updated.counterError
                        ]
                        ()
            , test "state_changed event resolves pending sync" <|
                \_ ->
                    let
                        baseModel =
                            modelForState WebSocket.Connected

                        model =
                            { baseModel | syncPending = True }

                        ( updated, _ ) =
                            update (ReceivedCloudEvent (stateChangedEvent 7 "sync")) model
                    in
                    Expect.all
                        [ \_ -> Expect.equal 7 updated.counter
                        , \_ -> Expect.equal False updated.syncPending
                        , \_ -> Expect.equal Nothing updated.counterError
                        ]
                        ()
            , test "reconnecting marks sync as pending" <|
                \_ ->
                    let
                        baseModel =
                            modelForState WebSocket.Connected

                        model =
                            { baseModel | syncPending = False }

                        ( updated, _ ) =
                            update (WebSocketMsg (WebSocket.ConnectionStatusChanged Ports.Reconnecting)) model
                    in
                    Expect.equal True updated.syncPending
            ]
        , describe "server error handling"
            [ test "counter server error events populate counterError" <|
                \_ ->
                    let
                        model =
                            modelForState WebSocket.Connected

                        ( updated, _ ) =
                            update (ReceivedCloudEvent (serverErrorEvent "rate limit exceeded")) model
                    in
                    Expect.equal (Just "rate limit exceeded") updated.counterError
            , test "malformed state_changed payload is tolerated and reported" <|
                \_ ->
                    let
                        model =
                            modelForState WebSocket.Connected

                        malformedEvent =
                            CloudEvents.new "urn:test"
                                "com.webui.counter.state_changed"
                                (Encode.object [ ( "count", Encode.string "oops" ) ])
                                |> CloudEvents.encodeToString

                        ( updated, _ ) =
                            update (ReceivedCloudEvent malformedEvent) model
                    in
                    Expect.equal (Just "Received malformed counter state payload from server.") updated.counterError
            , test "malformed CloudEvent envelope is tolerated and reported" <|
                \_ ->
                    let
                        model =
                            modelForState WebSocket.Connected

                        ( updated, _ ) =
                            update (ReceivedCloudEvent "{not valid json") model
                    in
                    Expect.equal (Just "Received malformed CloudEvent payload from server.") updated.counterError
            ]
        ]


modelForState : WebSocket.State -> Model
modelForState state =
    { wsModel =
        { state = state
        , queue = []
        , reconnectAttempts = 0
        , lastHeartbeat = Nothing
        }
    , page = CounterPage
    , flags =
        { websocketUrl = "ws://localhost:4000/socket"
        , pageMetadata = { title = Nothing, description = Nothing }
        }
    , key = Nothing
    , counter = 0
    , syncPending = False
    , counterError = Nothing
    }


stateChangedEvent : Int -> String -> String
stateChangedEvent count operation =
    CloudEvents.new "urn:test"
        "com.webui.counter.state_changed"
        (Encode.object
            [ ( "count", Encode.int count )
            , ( "operation", Encode.string operation )
            ]
        )
        |> CloudEvents.encodeToString


serverErrorEvent : String -> String
serverErrorEvent message =
    CloudEvents.new "urn:test"
        "com.webui.counter.server_error"
        (Encode.object [ ( "message", Encode.string message ) ])
        |> CloudEvents.encodeToString
