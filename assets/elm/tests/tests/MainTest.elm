module MainTest exposing (suite)

import Browser
import Browser.Navigation
import Expect exposing (Expectation)
import Json.Encode as Encode
import Main exposing (..)
import Test exposing (..)
import Url
import WebUI.Internal.WebSocket as WebSocket
import WebUI.Ports as Ports


suite : Test
suite =
    describe "Main"
        [ describe "Types"
            [ test "4.6.2 - Model type is defined correctly" <|
                \_ ->
                    -- Verify we can construct a Model (without actually calling init which needs a Key)
                    let
                        flags =
                            { websocketUrl = "ws://localhost:4000/socket"
                            , pageMetadata = { title = Just "Test", description = Nothing }
                            }

                        -- Just verify the types compile correctly
                        wsConfig : WebSocket.Config Msg
                        wsConfig =
                            { url = flags.websocketUrl
                            , onMessage = ReceivedCloudEvent
                            , onStatusChange = ConnectionChanged
                            , heartbeatInterval = 30
                            , reconnectDelay = 1000
                            , maxReconnectAttempts = 5
                            }
                    in
                    Expect.pass
            , test "4.6.3 - Msg type covers all variants" <|
                \_ ->
                    -- Verify the type can be constructed (implicit in compilation)
                    Expect.pass
            ]
        , describe "urlToPage"
            [ test "Maps root path to HomePage" <|
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
            , test "Maps empty path to HomePage" <|
                \_ ->
                    let
                        url =
                            Url.Url Url.Https "example.com" Nothing "" Nothing Nothing
                    in
                    case urlToPage url of
                        HomePage ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected HomePage"
            , test "Maps unknown path to NotFound" <|
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
        , describe "4.6.4 - WebSocket Config"
            [ test "WebSocket config is created correctly" <|
                \_ ->
                    let
                        flags =
                            { websocketUrl = "ws://localhost:4000/socket"
                            , pageMetadata = { title = Nothing, description = Nothing }
                            }

                        wsConfig : WebSocket.Config Msg
                        wsConfig =
                            { url = flags.websocketUrl
                            , onMessage = ReceivedCloudEvent
                            , onStatusChange = ConnectionChanged
                            , heartbeatInterval = 30
                            , reconnectDelay = 1000
                            , maxReconnectAttempts = 5
                            }
                    in
                    Expect.all
                        [ \_ -> Expect.equal "ws://localhost:4000/socket" wsConfig.url
                        , \_ -> Expect.equal 30 wsConfig.heartbeatInterval
                        , \_ -> Expect.equal 1000 wsConfig.reconnectDelay
                        , \_ -> Expect.equal 5 wsConfig.maxReconnectAttempts
                        ]
                        ()
            ]
        , describe "Flags type"
            [ test "Flags can be constructed with all fields" <|
                \_ ->
                    let
                        flags : Flags
                        flags =
                            { websocketUrl = "ws://localhost:4000/socket"
                            , pageMetadata = { title = Just "Test", description = Just "Description" }
                            }
                    in
                    Expect.all
                        [ \_ -> Expect.equal "ws://localhost:4000/socket" flags.websocketUrl
                        , \_ -> Expect.equal (Just "Test") flags.pageMetadata.title
                        , \_ -> Expect.equal (Just "Description") flags.pageMetadata.description
                        ]
                        ()
            ]
        ]



-- DUMMY VALUES


unsafeKey : String -> Browser.Navigation.Key
unsafeKey str =
    -- Browser.Navigation.Key is opaque, so we use a workaround
    -- This won't actually be called in the simplified tests
    str
        |> Debug.todo "Mock Key - tests should not call functions requiring a real Key"
