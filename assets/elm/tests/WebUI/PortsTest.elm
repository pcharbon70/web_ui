module WebUI.PortsTest exposing (suite)

import Expect exposing (Expectation)
import Test exposing (..)
import WebUI.Ports as Ports


suite : Test
suite =
    describe "WebUI.Ports"
        [ describe "ConnectionStatus type"
            [ test "4.4.3 - ConnectionStatus type covers all states" <|
                \_ ->
                    -- Just verify the type can be constructed
                    let
                        connecting =
                            Ports.Connecting

                        connected =
                            Ports.Connected

                        disconnected =
                            Ports.Disconnected

                        reconnecting =
                            Ports.Reconnecting

                        error =
                            Ports.Error "Test error"
                    in
                    -- All states should be constructable
                    Expect.pass
            ]
        , describe "parseConnectionStatus"
            [ test "Parses Connecting status" <|
                \_ ->
                    let
                        result =
                            Ports.parseConnectionStatus "Connecting"
                    in
                    case result of
                        Ports.Connecting ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected Connecting"
            , test "Parses Connected status" <|
                \_ ->
                    let
                        result =
                            Ports.parseConnectionStatus "Connected"
                    in
                    case result of
                        Ports.Connected ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected Connected"
            , test "Parses Disconnected status" <|
                \_ ->
                    let
                        result =
                            Ports.parseConnectionStatus "Disconnected"
                    in
                    case result of
                        Ports.Disconnected ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected Disconnected"
            , test "Parses Reconnecting status" <|
                \_ ->
                    let
                        result =
                            Ports.parseConnectionStatus "Reconnecting"
                    in
                    case result of
                        Ports.Reconnecting ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected Reconnecting"
            , test "Parses Error status with message" <|
                \_ ->
                    let
                        result =
                            Ports.parseConnectionStatus "Error:Connection failed"
                    in
                    case result of
                        Ports.Error message ->
                            Expect.equal "Connection failed" message

                        _ ->
                            Expect.fail "Expected Error with message"
            , test "Parses Error status with colon in message" <|
                \_ ->
                    let
                        result =
                            Ports.parseConnectionStatus "Error:Failed: timeout"
                    in
                    case result of
                        Ports.Error message ->
                            Expect.equal "Failed: timeout" message

                        _ ->
                            Expect.fail "Expected Error with full message"
            , test "Treats unknown status as Error" <|
                \_ ->
                    let
                        result =
                            Ports.parseConnectionStatus "UnknownStatus"
                    in
                    case result of
                        Ports.Error message ->
                            Expect.equal "UnknownStatus" message

                        _ ->
                            Expect.fail "Expected Error for unknown status"
            ]
        , describe "encodeConnectionStatus"
            [ test "Encodes Connecting status" <|
                \_ ->
                    let
                        result =
                            Ports.encodeConnectionStatus Ports.Connecting
                    in
                    Expect.equal "Connecting" result
            , test "Encodes Connected status" <|
                \_ ->
                    let
                        result =
                            Ports.encodeConnectionStatus Ports.Connected
                    in
                    Expect.equal "Connected" result
            , test "Encodes Disconnected status" <|
                \_ ->
                    let
                        result =
                            Ports.encodeConnectionStatus Ports.Disconnected
                    in
                    Expect.equal "Disconnected" result
            , test "Encodes Reconnecting status" <|
                \_ ->
                    let
                        result =
                            Ports.encodeConnectionStatus Ports.Reconnecting
                    in
                    Expect.equal "Reconnecting" result
            , test "Encodes Error status with message" <|
                \_ ->
                    let
                        result =
                            Ports.encodeConnectionStatus (Ports.Error "Test error")
                    in
                    Expect.equal "Error:Test error" result
            ]
        , describe "Round-trip encoding/decoding"
            [ test "Round-trips Connecting status" <|
                \_ ->
                    let
                        original =
                            Ports.Connecting

                        encoded =
                            Ports.encodeConnectionStatus original

                        decoded =
                            Ports.parseConnectionStatus encoded
                    in
                    case decoded of
                        Ports.Connecting ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected Connecting after round-trip"
            , test "Round-trips Connected status" <|
                \_ ->
                    let
                        original =
                            Ports.Connected

                        encoded =
                            Ports.encodeConnectionStatus original

                        decoded =
                            Ports.parseConnectionStatus encoded
                    in
                    case decoded of
                        Ports.Connected ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected Connected after round-trip"
            , test "Round-trips Disconnected status" <|
                \_ ->
                    let
                        original =
                            Ports.Disconnected

                        encoded =
                            Ports.encodeConnectionStatus original

                        decoded =
                            Ports.parseConnectionStatus encoded
                    in
                    case decoded of
                        Ports.Disconnected ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected Disconnected after round-trip"
            , test "Round-trips Reconnecting status" <|
                \_ ->
                    let
                        original =
                            Ports.Reconnecting

                        encoded =
                            Ports.encodeConnectionStatus original

                        decoded =
                            Ports.parseConnectionStatus encoded
                    in
                    case decoded of
                        Ports.Reconnecting ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected Reconnecting after round-trip"
            , test "Round-trips Error status" <|
                \_ ->
                    let
                        original =
                            Ports.Error "Test error"

                        encoded =
                            Ports.encodeConnectionStatus original

                        decoded =
                            Ports.parseConnectionStatus encoded
                    in
                    case decoded of
                        Ports.Error message ->
                            Expect.equal "Test error" message

                        _ ->
                            Expect.fail "Expected Error after round-trip"
            ]
        ]
