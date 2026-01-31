module WebUI.Internal.WebSocketTest exposing (suite)

import Expect exposing (Expectation)
import Process
import Task
import Test exposing (..)
import WebUI.Internal.WebSocket as WebSocket
import WebUI.Ports as Ports


suite : Test
suite =
    describe "WebUI.Internal.WebSocket"
        [ describe "State type"
            [ test "4.5.2 - State type covers all connection states" <|
                \_ ->
                    -- Verify all states can be constructed
                    let
                        connecting =
                            WebSocket.Connecting

                        connected =
                            WebSocket.Connected

                        reconnecting =
                            WebSocket.Reconnecting 1

                        disconnected =
                            WebSocket.Disconnected

                        error =
                            WebSocket.Error "Test error"
                    in
                    Expect.pass
            ]
        , describe "init"
            [ test "4.5.1 - init creates initial state" <|
                \_ ->
                    let
                        config =
                            { url = "ws://localhost:4000/socket"
                            , onMessage = always DummyMessage
                            , onStatusChange = always DummyStatus
                            , heartbeatInterval = 30
                            , reconnectDelay = 1000
                            , maxReconnectAttempts = 5
                            }

                        ( model, _ ) =
                            WebSocket.init config
                    in
                    Expect.all
                        [ \_ -> Expect.equal True (model.state == WebSocket.Connecting)
                        , \_ -> Expect.equal True (List.isEmpty model.queue)
                        , \_ -> Expect.equal 0 model.reconnectAttempts
                        ]
                        ()
            ]
        , describe "send"
            [ test "4.5.2 - send queues message when disconnected" <|
                \_ ->
                    let
                        config =
                            { url = "ws://localhost:4000/socket"
                            , onMessage = always DummyMessage
                            , onStatusChange = always DummyStatus
                            , heartbeatInterval = 30
                            , reconnectDelay = 1000
                            , maxReconnectAttempts = 5
                            }

                        model =
                            { state = WebSocket.Disconnected
                            , queue = []
                            , reconnectAttempts = 0
                            , lastHeartbeat = Nothing
                            }

                        ( newModel, _ ) =
                            WebSocket.send "test message" model config
                    in
                    Expect.equal [ "test message" ] newModel.queue
            , test "send sends immediately when connected" <|
                \_ ->
                    let
                        config =
                            { url = "ws://localhost:4000/socket"
                            , onMessage = always DummyMessage
                            , onStatusChange = always DummyStatus
                            , heartbeatInterval = 30
                            , reconnectDelay = 1000
                            , maxReconnectAttempts = 5
                            }

                        model =
                            { state = WebSocket.Connected
                            , queue = []
                            , reconnectAttempts = 0
                            , lastHeartbeat = Nothing
                            }

                        ( newModel, _ ) =
                            WebSocket.send "test message" model config
                    in
                    Expect.equal True (List.isEmpty newModel.queue)
            ]
        , describe "calculateBackoff"
            [ test "4.5.6 - exponential backoff calculation" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal 1000 (WebSocket.calculateBackoff 0)
                        , \_ -> Expect.equal 2000 (WebSocket.calculateBackoff 1)
                        , \_ -> Expect.equal 4000 (WebSocket.calculateBackoff 2)
                        , \_ -> Expect.equal 8000 (WebSocket.calculateBackoff 3)
                        , \_ -> Expect.equal 16000 (WebSocket.calculateBackoff 4)
                        ]
                        ()
            , test "4.5.6 - backoff caps at 30 seconds" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal 30000 (WebSocket.calculateBackoff 10)
                        , \_ -> Expect.equal 30000 (WebSocket.calculateBackoff 20)
                        , \_ -> Expect.equal 30000 (WebSocket.calculateBackoff 100)
                        ]
                        ()
            ]
        , describe "isConnected"
            [ test "Returns True when Connected" <|
                \_ ->
                    let
                        model =
                            { state = WebSocket.Connected
                            , queue = []
                            , reconnectAttempts = 0
                            , lastHeartbeat = Nothing
                            }
                    in
                    Expect.equal True (WebSocket.isConnected model)
            , test "Returns False when Disconnected" <|
                \_ ->
                    let
                        model =
                            { state = WebSocket.Disconnected
                            , queue = []
                            , reconnectAttempts = 0
                            , lastHeartbeat = Nothing
                            }
                    in
                    Expect.equal False (WebSocket.isConnected model)
            , test "Returns False when Connecting" <|
                \_ ->
                    let
                        model =
                            { state = WebSocket.Connecting
                            , queue = []
                            , reconnectAttempts = 0
                            , lastHeartbeat = Nothing
                            }
                    in
                    Expect.equal False (WebSocket.isConnected model)
            , test "Returns False when Error" <|
                \_ ->
                    let
                        model =
                            { state = WebSocket.Error "Connection failed"
                            , queue = []
                            , reconnectAttempts = 0
                            , lastHeartbeat = Nothing
                            }
                    in
                    Expect.equal False (WebSocket.isConnected model)
            ]
        , describe "getState"
            [ test "Returns current state" <|
                \_ ->
                    let
                        model =
                            { state = WebSocket.Connected
                            , queue = []
                            , reconnectAttempts = 0
                            , lastHeartbeat = Nothing
                            }
                    in
                    case WebSocket.getState model of
                        WebSocket.Connected ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected Connected state"
            ]
        , describe "update"
            [ test "4.5.5 - connection status transitions" <|
                \_ ->
                    let
                        config =
                            { url = "ws://localhost:4000/socket"
                            , onMessage = always DummyMessage
                            , onStatusChange = always DummyStatus
                            , heartbeatInterval = 30
                            , reconnectDelay = 1000
                            , maxReconnectAttempts = 5
                            }

                        model =
                            { state = WebSocket.Connecting
                            , queue = []
                            , reconnectAttempts = 0
                            , lastHeartbeat = Nothing
                            }

                        ( newModel, _ ) =
                            WebSocket.update (WebSocket.ConnectionStatusChanged Ports.Connected) model config
                    in
                    case newModel.state of
                        WebSocket.Connected ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected Connected state"
            , test "4.5.3 - reconnect updates state correctly" <|
                \_ ->
                    let
                        config =
                            { url = "ws://localhost:4000/socket"
                            , onMessage = always DummyMessage
                            , onStatusChange = always DummyStatus
                            , heartbeatInterval = 30
                            , reconnectDelay = 1000
                            , maxReconnectAttempts = 5
                            }

                        model =
                            { state = WebSocket.Disconnected
                            , queue = []
                            , reconnectAttempts = 2
                            , lastHeartbeat = Nothing
                            }

                        ( newModel, _ ) =
                            WebSocket.update WebSocket.AttemptReconnect model config
                    in
                    case newModel.state of
                        WebSocket.Reconnecting attempt ->
                            Expect.equal 3 newModel.reconnectAttempts

                        _ ->
                            Expect.fail "Expected Reconnecting state"
            , test "4.5.4 - heartbeat updates last activity" <|
                \_ ->
                    let
                        config =
                            { url = "ws://localhost:4000/socket"
                            , onMessage = always DummyMessage
                            , onStatusChange = always DummyStatus
                            , heartbeatInterval = 30
                            , reconnectDelay = 1000
                            , maxReconnectAttempts = 5
                            }

                        model =
                            { state = WebSocket.Connected
                            , queue = []
                            , reconnectAttempts = 0
                            , lastHeartbeat = Nothing
                            }

                        ( newModel, _ ) =
                            WebSocket.update WebSocket.Heartbeat model config
                    in
                    case newModel.lastHeartbeat of
                        Just _ ->
                            Expect.pass

                        Nothing ->
                            Expect.fail "Expected lastHeartbeat to be set"
            ]
        ]



-- DUMMY TYPES FOR TESTING


type DummyMsg
    = DummyMessage
    | DummyStatus
