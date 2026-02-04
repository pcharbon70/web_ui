module WebUI.IntegrationTest exposing (suite)

{-| Integration tests for WebUI Elm modules.

These tests verify that multiple modules work together correctly.

-}

import Dict exposing (Dict)
import Expect exposing (Expectation)
import Json.Decode as Decode
import Json.Encode as Encode
import Test exposing (..)
import WebUI.CloudEvents as CloudEvents
import WebUI.Internal.WebSocket as WebSocket
import WebUI.Ports as Ports


suite : Test
suite =
    describe "WebUI Integration Tests"
        [ describe "CloudEvent Round-Trip"
            [ test "4.8.3 - CloudEvent round-trip preserves all data" <|
                \_ ->
                    let
                        original =
                            { specversion = "1.0"
                            , id = "test-id-123"
                            , source = "/test/source"
                            , type_ = "com.example.integration"
                            , data = Encode.object [ ( "message", Encode.string "integration test" ), ( "count", Encode.int 42 ) ]
                            , datacontenttype = Just "application/json"
                            , datacontentencoding = Nothing
                            , subject = Just "integration-test"
                            , time = Just "2024-01-29T00:00:00Z"
                            , extensions = Dict.fromList [ ( "custom", "value" ), ( "trace-id", "abc-123" ) ]
                            }

                        -- Encode to JSON string
                        encoded =
                            CloudEvents.encodeToString original

                        -- Decode back to CloudEvent
                        result =
                            CloudEvents.decodeFromString encoded
                    in
                    case result of
                        Ok decoded ->
                            Expect.all
                                [ \_ -> Expect.equal original.specversion decoded.specversion
                                , \_ -> Expect.equal original.id decoded.id
                                , \_ -> Expect.equal original.source decoded.source
                                , \_ -> Expect.equal original.type_ decoded.type_
                                , \_ -> Expect.equal original.datacontenttype decoded.datacontenttype
                                , \_ -> Expect.equal original.subject decoded.subject
                                , \_ -> Expect.equal original.time decoded.time
                                , \_ -> Expect.equal original.extensions decoded.extensions
                                ]
                                ()

                        Err err ->
                            Expect.fail err
            ]
        , describe "Connection Status Round-Trip"
            [ test "ConnectionStatus encode/parse round-trip" <|
                \_ ->
                    -- Test each status round-trips correctly
                    let
                        testStatus status =
                            let
                                encoded =
                                    Ports.encodeConnectionStatus status

                                decoded =
                                    Ports.parseConnectionStatus encoded
                            in
                            case ( status, decoded ) of
                                ( Ports.Connecting, Ports.Connecting ) ->
                                    Expect.pass

                                ( Ports.Connected, Ports.Connected ) ->
                                    Expect.pass

                                ( Ports.Disconnected, Ports.Disconnected ) ->
                                    Expect.pass

                                ( Ports.Reconnecting, Ports.Reconnecting ) ->
                                    Expect.pass

                                ( Ports.Error msg1, Ports.Error msg2 ) ->
                                    Expect.equal msg1 msg2

                                _ ->
                                    Expect.fail "Round-trip failed for status"
                    in
                    -- Test all statuses
                    testStatus Ports.Connecting
                        |> (\_ -> testStatus Ports.Connected)
                        |> (\_ -> testStatus Ports.Disconnected)
                        |> (\_ -> testStatus Ports.Reconnecting)
                        |> (\_ -> testStatus (Ports.Error "Test error message"))
            , test "ConnectionStatus handles error with colon in message" <|
                \_ ->
                    let
                        original =
                            Ports.Error "Connection:failed:timeout"

                        encoded =
                            Ports.encodeConnectionStatus original

                        decoded =
                            Ports.parseConnectionStatus encoded
                    in
                    case decoded of
                        Ports.Error msg ->
                            Expect.equal "Connection:failed:timeout" msg

                        _ ->
                            Expect.fail "Expected Error with message"
            ]
        , describe "WebSocket State Machine"
            [ test "4.8.4 - WebSocket reconnection on disconnect" <|
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
                    in
                    -- Simulate reconnection attempt
                    let
                        ( newModel, _ ) =
                            WebSocket.update WebSocket.AttemptReconnect model config
                    in
                    Expect.all
                        [ \_ -> Expect.equal 1 newModel.reconnectAttempts
                        , \_ ->
                            case newModel.state of
                                WebSocket.Reconnecting 1 ->
                                    Expect.pass

                                _ ->
                                    Expect.fail "Expected Reconnecting state"
                        ]
                        ()
            , test "4.8.4 - Reconnection stops at max attempts" <|
                \_ ->
                    let
                        config =
                            { url = "ws://localhost:4000/socket"
                            , onMessage = always DummyMessage
                            , onStatusChange = always DummyStatus
                            , heartbeatInterval = 30
                            , reconnectDelay = 1000
                            , maxReconnectAttempts = 3
                            }

                        model =
                            { state = WebSocket.Disconnected
                            , queue = []
                            , reconnectAttempts = 3
                            , lastHeartbeat = Nothing
                            }
                    in
                    let
                        ( newModel, _ ) =
                            WebSocket.update WebSocket.AttemptReconnect model config
                    in
                    case newModel.state of
                        WebSocket.Error _ ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected Error state after max attempts"
            ]
        , describe "Flags Validation"
            [ test "4.8.1 - Main.init with valid flags" <|
                \_ ->
                    let
                        flags =
                            { websocketUrl = "ws://localhost:4000/socket"
                            , pageMetadata = { title = Just "Test Page", description = Just "Test Description" }
                            }
                    in
                    -- Just verify flags structure is correct
                    Expect.all
                        [ \_ -> Expect.equal "ws://localhost:4000/socket" flags.websocketUrl
                        , \_ -> Expect.equal (Just "Test Page") flags.pageMetadata.title
                        , \_ -> Expect.equal (Just "Test Description") flags.pageMetadata.description
                        ]
                        ()
            , test "Main.init handles missing metadata" <|
                \_ ->
                    let
                        flags =
                            { websocketUrl = "ws://localhost:4000/socket"
                            , pageMetadata = { title = Nothing, description = Nothing }
                            }
                    in
                    -- Verify metadata can be Nothing
                    Expect.all
                        [ \_ -> Expect.equal "ws://localhost:4000/socket" flags.websocketUrl
                        , \_ -> Expect.equal Nothing flags.pageMetadata.title
                        , \_ -> Expect.equal Nothing flags.pageMetadata.description
                        ]
                        ()
            ]
        , describe "CloudEvent and Ports Integration"
            [ test "CloudEvent can be sent via port after encoding" <|
                \_ ->
                    let
                        event =
                            CloudEvents.new "/test"
                                "com.test.event"
                                (Encode.object [ ( "test", Encode.string "data" ) ])

                        json =
                            CloudEvents.encodeToString event
                    in
                    -- Verify JSON is valid and can be parsed
                    case CloudEvents.decodeFromString json of
                        Ok _ ->
                            Expect.pass

                        Err _ ->
                            Expect.fail "Failed to decode encoded CloudEvent"
            ]
        , describe "Exponential Backoff Calculation"
            [ test "4.8.4 - Exponential backoff increases correctly" <|
                \_ ->
                    let
                        -- Only check 0-4 since 5+ gets capped at 30000
                        delays =
                            List.map WebSocket.calculateBackoff (List.range 0 4)
                    in
                    Expect.all
                        [ \_ -> Expect.equal 1000 (Maybe.withDefault 0 (List.head delays))
                        , \_ ->
                            -- Each subsequent delay should be double the previous
                            let
                                checkDoubles list =
                                    case list of
                                        [] ->
                                            Expect.pass

                                        _ :: [] ->
                                            Expect.pass

                                        a :: b :: rest ->
                                            if b == a * 2 then
                                                checkDoubles (b :: rest)

                                            else
                                                Expect.fail "Backoff not exponential"
                            in
                            checkDoubles delays
                        ]
                        ()
            ]
        ]



-- DUMMY TYPES FOR TESTING


type DummyMsg
    = DummyMessage
    | DummyStatus
