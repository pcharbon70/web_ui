module WebUI.CloudEventsTest exposing (suite)

import Dict exposing (Dict)
import Expect exposing (Expectation)
import Json.Decode as Decode
import Json.Encode as Encode
import Test exposing (..)
import WebUI.CloudEvents as CloudEvents


suite : Test
suite =
    describe "WebUI.CloudEvents"
        [ describe "CloudEvent type"
            [ test "4.2.1 - CloudEvent type creates valid record" <|
                \_ ->
                    let
                        event =
                            CloudEvents.newWithId
                                "test-id"
                                "/test-source"
                                "com.test.event"
                                (Encode.object [ ( "message", Encode.string "Hello" ) ])
                    in
                    Expect.all
                        [ \_ -> Expect.equal "1.0" event.specversion
                        , \_ -> Expect.equal "test-id" event.id
                        , \_ -> Expect.equal "/test-source" event.source
                        , \_ -> Expect.equal "com.test.event" event.type_
                        ]
                        ()
            ]
        , describe "encodeCloudEvent"
            [ test "4.2.3 - Encoder produces valid JSON structure" <|
                \_ ->
                    let
                        event =
                            CloudEvents.newWithId
                                "test-id"
                                "/test-source"
                                "com.test.event"
                                (Encode.object [ ( "message", Encode.string "Hello" ) ])

                        encoded =
                            CloudEvents.encodeCloudEvent event
                                |> Encode.encode 0
                                |> Decode.decodeString
                                    (Decode.field "specversion" Decode.string
                                        |> Decode.andThen
                                            (\specVersion ->
                                                Decode.field "id" Decode.string
                                                    |> Decode.map (\id -> ( specVersion, id ))
                                            )
                                    )
                    in
                    case encoded of
                        Ok ( specVersion, id ) ->
                            Expect.equal "1.0" specVersion
                                |> (\_ -> Expect.equal "test-id" id)

                        Err _ ->
                            Expect.fail "Failed to decode encoded event"
            , test "Encoder includes optional fields when present" <|
                \_ ->
                    let
                        event =
                            { specversion = "1.0"
                            , id = "test-id"
                            , source = "/test-source"
                            , type_ = "com.test.event"
                            , data = Encode.null
                            , datacontenttype = Just "application/json"
                            , datacontentencoding = Just "base64"
                            , subject = Just "test-subject"
                            , time = Just "2024-01-01T00:00:00Z"
                            , extensions = Dict.fromList [ ( "custom", "value" ) ]
                            }

                        encoded =
                            CloudEvents.encodeCloudEvent event
                                |> Encode.encode 0
                                |> Decode.decodeString
                                    (Decode.map5
                                        (\c d e s t ->
                                            { contentType = c
                                            , encoding = d
                                            , subject = e
                                            , timeVal = s
                                            , custom = t
                                            }
                                        )
                                        (Decode.field "datacontenttype" Decode.string)
                                        (Decode.field "datacontentencoding" Decode.string)
                                        (Decode.field "subject" Decode.string)
                                        (Decode.field "time" Decode.string)
                                        (Decode.field "custom" Decode.string)
                                    )
                    in
                    case encoded of
                        Ok result ->
                            Expect.all
                                [ \_ -> Expect.equal "application/json" result.contentType
                                , \_ -> Expect.equal "base64" result.encoding
                                , \_ -> Expect.equal "test-subject" result.subject
                                , \_ -> Expect.equal "2024-01-01T00:00:00Z" result.timeVal
                                , \_ -> Expect.equal "value" result.custom
                                ]
                                ()

                        Err _ ->
                            Expect.fail "Failed to decode optional fields"
            ]
        , describe "decodeCloudEvent"
            [ test "4.2.2 - Decoder parses valid JSON" <|
                \_ ->
                    let
                        json =
                            """{"specversion":"1.0","id":"test-id","source":"/test","type":"com.test","data":{}}"""

                        result =
                            CloudEvents.decodeFromString json
                    in
                    case result of
                        Ok event ->
                            Expect.all
                                [ \_ -> Expect.equal "1.0" event.specversion
                                , \_ -> Expect.equal "test-id" event.id
                                , \_ -> Expect.equal "/test" event.source
                                , \_ -> Expect.equal "com.test" event.type_
                                ]
                                ()

                        Err err ->
                            Expect.fail err
            , test "4.2.5 - Decoder fails on missing required field" <|
                \_ ->
                    let
                        -- Missing 'type' field
                        json =
                            """{"specversion":"1.0","id":"test-id","source":"/test","data":{}}"""

                        result =
                            CloudEvents.decodeFromString json
                    in
                    case result of
                        Err _ ->
                            Expect.pass

                        Ok _ ->
                            Expect.fail "Expected decode to fail with missing required field"
            , test "4.2.6 - Decoder handles optional fields" <|
                \_ ->
                    let
                        json =
                            """{"specversion":"1.0","id":"test-id","source":"/test","type":"com.test","data":{},"datacontenttype":"text/plain","subject":"test-subject"}"""

                        result =
                            CloudEvents.decodeFromString json
                    in
                    case result of
                        Ok event ->
                            Expect.all
                                [ \_ -> Expect.equal (Just "text/plain") event.datacontenttype
                                , \_ -> Expect.equal (Just "test-subject") event.subject
                                , \_ -> Expect.equal Nothing event.datacontentencoding
                                , \_ -> Expect.equal Nothing event.time
                                ]
                                ()

                        Err err ->
                            Expect.fail err
            , test "4.2.7 - Decoder validates specversion is 1.0" <|
                \_ ->
                    let
                        -- Invalid specversion
                        json =
                            """{"specversion":"0.3","id":"test-id","source":"/test","type":"com.test","data":{}}"""

                        result =
                            CloudEvents.decodeFromString json
                    in
                    case result of
                        Err _ ->
                            Expect.pass

                        Ok _ ->
                            Expect.fail "Expected decode to fail with invalid specversion"
            , test "4.2.7 - Extensions are preserved" <|
                \_ ->
                    let
                        json =
                            """{"specversion":"1.0","id":"test-id","source":"/test","type":"com.test","data":{},"customattr":"customvalue","another":"123"}"""

                        result =
                            CloudEvents.decodeFromString json
                    in
                    case result of
                        Ok event ->
                            Expect.all
                                [ \_ ->
                                    event.extensions
                                        |> Dict.get "customattr"
                                        |> Expect.equal (Just "customvalue")
                                , \_ ->
                                    event.extensions
                                        |> Dict.get "another"
                                        |> Expect.equal (Just "123")
                                ]
                                ()

                        Err err ->
                            Expect.fail err
            ]
        , describe "Round-trip encoding/decoding"
            [ test "4.2.4 - Round-trip preserves all data" <|
                \_ ->
                    let
                        original =
                            { specversion = "1.0"
                            , id = "test-id"
                            , source = "/test-source"
                            , type_ = "com.test.event"
                            , data = Encode.object [ ( "message", Encode.string "Hello" ), ( "count", Encode.int 42 ) ]
                            , datacontenttype = Just "application/json"
                            , datacontentencoding = Just "utf-8"
                            , subject = Just "test-subject"
                            , time = Just "2024-01-01T00:00:00Z"
                            , extensions = Dict.fromList [ ( "custom", "value" ), ( "extension", "data" ) ]
                            }

                        encoded =
                            CloudEvents.encodeToString original

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
                                , \_ -> Expect.equal original.datacontentencoding decoded.datacontentencoding
                                , \_ -> Expect.equal original.subject decoded.subject
                                , \_ -> Expect.equal original.time decoded.time
                                , \_ -> Expect.equal original.extensions decoded.extensions
                                ]
                                ()

                        Err err ->
                            Expect.fail err
            ]
        , describe "new function"
            [ test "new creates event with default values" <|
                \_ ->
                    let
                        event =
                            CloudEvents.new "/test" "com.test" Encode.null
                    in
                    Expect.all
                        [ \_ -> Expect.equal "1.0" event.specversion
                        , \_ -> Expect.equal "application/json" (Maybe.withDefault "" event.datacontenttype)
                        , \_ -> Expect.equal Nothing event.datacontentencoding
                        , \_ -> Expect.equal Nothing event.subject
                        , \_ -> Expect.equal Nothing event.time
                        , \_ -> Expect.equal True (Dict.isEmpty event.extensions)
                        ]
                        ()
            , test "new generates UUID-like ID" <|
                \_ ->
                    let
                        event =
                            CloudEvents.new "/test" "com.test" Encode.null

                        -- UUID format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
                        parts =
                            String.split "-" event.id
                    in
                    Expect.all
                        [ \_ -> Expect.equal 5 (List.length parts)
                        , \_ -> Expect.equal 8 (String.length (Maybe.withDefault "" (List.head parts)))
                        , \_ -> Expect.equal 4 (String.length (Maybe.withDefault "" (List.drop 1 parts |> List.head)))
                        , \_ ->
                            -- Third part should start with '4' for UUID v4
                            Expect.equal True
                                (Maybe.withDefault "" (List.drop 2 parts |> List.head)
                                    |> String.startsWith "4"
                                )
                        ]
                        ()
            ]
        , describe "generateUuid"
            [ test "generateUuid produces valid UUID format" <|
                \_ ->
                    let
                        uuid =
                            CloudEvents.generateUuid ()

                        parts =
                            String.split "-" uuid
                    in
                    Expect.all
                        [ \_ -> Expect.equal 5 (List.length parts)
                        , \_ -> Expect.equal 8 (String.length (Maybe.withDefault "" (List.head parts)))
                        , \_ -> Expect.equal 4 (String.length (Maybe.withDefault "" (List.drop 1 parts |> List.head)))
                        , \_ -> Expect.equal 4 (String.length (Maybe.withDefault "" (List.drop 2 parts |> List.head)))
                        , \_ -> Expect.equal 4 (String.length (Maybe.withDefault "" (List.drop 3 parts |> List.head)))
                        , \_ -> Expect.equal 12 (String.length (Maybe.withDefault "" (List.drop 4 parts |> List.head)))
                        , \_ ->
                            -- Third part should start with '4' for UUID v4
                            Expect.equal True
                                (Maybe.withDefault "" (List.drop 2 parts |> List.head)
                                    |> String.startsWith "4"
                                )
                        ]
                        ()
            , test "generateUuid produces only hex characters and hyphens" <|
                \_ ->
                    let
                        uuid =
                            CloudEvents.generateUuid ()

                        validChars =
                            "0123456789abcdef-"

                        isValidChar =
                            \c ->
                                String.contains (String.fromChar c) validChars

                        allValid =
                            String.toList uuid
                                |> List.all isValidChar
                    in
                    Expect.equal True allValid
            ]
        , describe "encodeToString / decodeFromString"
            [ test "Can encode and decode as string" <|
                \_ ->
                    let
                        event =
                            CloudEvents.newWithId
                                "test-id"
                                "/source"
                                "com.event"
                                (Encode.string "data")

                        encoded =
                            CloudEvents.encodeToString event

                        decoded =
                            CloudEvents.decodeFromString encoded
                    in
                    case decoded of
                        Ok decodedEvent ->
                            Expect.equal decodedEvent.source event.source

                        Err err ->
                            Expect.fail err
            ]
        , describe "4.3 - Field Validation"
            [ describe "URI validation for source field"
                [ test "4.3.1 - Accepts relative URI starting with /" <|
                    \_ ->
                        let
                            json =
                                """{"specversion":"1.0","id":"test-id","source":"/my-context","type":"com.test","data":{}}"""

                            result =
                                CloudEvents.decodeFromString json
                        in
                        case result of
                            Ok event ->
                                Expect.equal "/my-context" event.source

                            Err err ->
                                Expect.fail err
                , test "4.3.2 - Accepts absolute URI with scheme" <|
                    \_ ->
                        let
                            json =
                                """{"specversion":"1.0","id":"test-id","source":"https://example.com/context","type":"com.test","data":{}}"""

                            result =
                                CloudEvents.decodeFromString json
                        in
                        case result of
                            Ok event ->
                                Expect.equal "https://example.com/context" event.source

                            Err err ->
                                Expect.fail err
                , test "4.3.3 - Rejects invalid source URI" <|
                    \_ ->
                        let
                            json =
                                """{"specversion":"1.0","id":"test-id","source":"not-a-uri","type":"com.test","data":{}}"""

                            result =
                                CloudEvents.decodeFromString json
                        in
                        case result of
                            Err _ ->
                                Expect.pass

                            Ok _ ->
                                Expect.fail "Expected decode to fail with invalid source"
                ]
            , describe "ISO 8601 timestamp validation"
                [ test "4.3.4 - Accepts valid ISO 8601 timestamp with Z" <|
                    \_ ->
                        let
                            json =
                                """{"specversion":"1.0","id":"test-id","source":"/test","type":"com.test","data":{},"time":"2024-01-01T00:00:00Z"}"""

                            result =
                                CloudEvents.decodeFromString json
                        in
                        case result of
                            Ok event ->
                                Expect.equal (Just "2024-01-01T00:00:00Z") event.time

                            Err err ->
                                Expect.fail err
                , test "4.3.5 - Accepts valid ISO 8601 timestamp with milliseconds" <|
                    \_ ->
                        let
                            json =
                                """{"specversion":"1.0","id":"test-id","source":"/test","type":"com.test","data":{},"time":"2024-01-01T00:00:00.123Z"}"""

                            result =
                                CloudEvents.decodeFromString json
                        in
                        case result of
                            Ok event ->
                                Expect.equal (Just "2024-01-01T00:00:00.123Z") event.time

                            Err err ->
                                Expect.fail err
                , test "4.3.6 - Accepts valid ISO 8601 timestamp with timezone offset" <|
                    \_ ->
                        let
                            json =
                                """{"specversion":"1.0","id":"test-id","source":"/test","type":"com.test","data":{},"time":"2024-01-01T00:00:00+00:00"}"""

                            result =
                                CloudEvents.decodeFromString json
                        in
                        case result of
                            Ok event ->
                                Expect.equal (Just "2024-01-01T00:00:00+00:00") event.time

                            Err err ->
                                Expect.fail err
                , test "4.3.7 - Rejects invalid timestamp format" <|
                    \_ ->
                        let
                            json =
                                """{"specversion":"1.0","id":"test-id","source":"/test","type":"com.test","data":{},"time":"2024-01-01 00:00:00"}"""

                            result =
                                CloudEvents.decodeFromString json
                        in
                        case result of
                            Err _ ->
                                Expect.pass

                            Ok _ ->
                                Expect.fail "Expected decode to fail with invalid timestamp"
                ]
            , describe "4.3.8 - Custom error messages"
                [ test "Error message includes field information for invalid specversion" <|
                    \_ ->
                        let
                            json =
                                """{"specversion":"0.3","id":"test-id","source":"/test","type":"com.test","data":{}}"""

                            result =
                                CloudEvents.decodeFromString json
                        in
                        case result of
                            Err errMsg ->
                                -- Check that error mentions specversion
                                Expect.equal True (String.contains "specversion" errMsg)

                            Ok _ ->
                                Expect.fail "Expected decode to fail"
                , test "Error message includes field information for invalid source" <|
                    \_ ->
                        let
                            json =
                                """{"specversion":"1.0","id":"test-id","source":"invalid-uri","type":"com.test","data":{}}"""

                            result =
                                CloudEvents.decodeFromString json
                        in
                        case result of
                            Err errMsg ->
                                -- Check that error mentions source/URI
                                Expect.equal True (String.contains "source" errMsg || String.contains "URI" errMsg)

                            Ok _ ->
                                Expect.fail "Expected decode to fail"
                , test "Error message includes field information for invalid time" <|
                    \_ ->
                        let
                            json =
                                """{"specversion":"1.0","id":"test-id","source":"/test","type":"com.test","data":{},"time":"invalid-time"}"""

                            result =
                                CloudEvents.decodeFromString json
                        in
                        case result of
                            Err errMsg ->
                                -- Check that error mentions time or ISO 8601
                                Expect.equal True (String.contains "time" errMsg || String.contains "ISO 8601" errMsg)

                            Ok _ ->
                                Expect.fail "Expected decode to fail"
                ]
            ]
        ]
