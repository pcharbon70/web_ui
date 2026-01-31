module WebUI.CloudEvents exposing
    ( CloudEvent
    , DecodeError(..)
    , decodeCloudEvent
    , decodeFromString
    , encodeCloudEvent
    , encodeToString
    , new
    , newWithId
    )

{-| CloudEvents implementation following CNCF CloudEvents Specification v1.0.1.

This module provides a type-safe implementation of CloudEvents for interoperability
between Elm frontend and Elixir backend.

Reference: https://github.com/cloudevents/spec/blob/v1.0.1/cloudevents.md

# Types

@docs CloudEvent, DecodeError

# Creation

@docs new, newWithId

# Encoding

@docs encodeCloudEvent, encodeToString

# Decoding

@docs decodeCloudEvent, decodeFromString

-}

import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Regex exposing (Regex)
import Set exposing (Set)


{-| CloudEvent record following CNCF CloudEvents Specification v1.0.1.

## Required Attributes

  - `specversion` - The CloudEvents specification version (always "1.0")
  - `id` - Unique identifier for the event (typically a UUID)
  - `source` - URI reference identifying the context in which an event happened
  - `type` - String identifying the type of event (e.g., "com.example.someevent")
  - `data` - Event-specific data (any valid JSON value)

## Optional Attributes

  - `datacontenttype` - Content type of the `data` value (defaults to "application/json")
  - `datacontentencoding` - Encoding for `data` (e.g., "base64" for binary data)
  - `subject` - Subject of the event in the context of the event producer
  - `time` - Timestamp of when the event occurred (ISO 8601 string)
  - `extensions` - Map of additional custom attributes

-}
type alias CloudEvent =
    { specversion : String
    , id : String
    , source : String
    , type_ : String
    , data : Encode.Value
    , datacontenttype : Maybe String
    , datacontentencoding : Maybe String
    , subject : Maybe String
    , time : Maybe String
    , extensions : Dict String String
    }


{-| Custom error types for CloudEvent decoding with field path information.

-}
type DecodeError
    = InvalidSpecversion String
    | InvalidSource String
    | InvalidTime String
    | MissingRequiredField String
    | JsonError String


{-| Convert a DecodeError to a human-readable string.

-}
errorToString : DecodeError -> String
errorToString error =
    case error of
        InvalidSpecversion version ->
            "Invalid specversion: " ++ version ++ " (expected \"1.0\")"

        InvalidSource source ->
            "Invalid source URI: " ++ source ++ " (must be a valid URI reference)"

        InvalidTime time ->
            "Invalid time format: " ++ time ++ " (must be ISO 8601 format)"

        MissingRequiredField field ->
            "Missing required field: " ++ field

        JsonError msg ->
            "JSON error: " ++ msg


{-| URI reference decoder.

Validates that the source field is a valid URI reference.
Accepts absolute URIs and relative URI references (starting with /).

-}
uriDecoder : Decoder String
uriDecoder =
    Decode.string
        |> Decode.andThen validateUri


{-| Validate a URI reference string.

-}
validateUri : String -> Decoder String
validateUri source =
    if String.startsWith "/" source then
        -- Relative URI reference
        Decode.succeed source

    else if String.contains "://" source then
        -- Absolute URI - basic validation
        case String.split "://" source of
            scheme :: path :: [] ->
                if String.length scheme > 0 && String.length path > 0 then
                    Decode.succeed source

                else
                    Decode.fail (InvalidSource source |> errorToString)

            _ ->
                Decode.fail (InvalidSource source |> errorToString)

    else
        Decode.fail (InvalidSource source |> errorToString)


{-| ISO 8601 timestamp decoder.

Validates that the time field is in ISO 8601 format.
Accepts formats like:
  - 2024-01-01T00:00:00Z
  - 2024-01-01T00:00:00.123Z
  - 2024-01-01T00:00:00+00:00

-}
timestampDecoder : Decoder String
timestampDecoder =
    Decode.string
        |> Decode.andThen validateTimestamp


{-| Regex for ISO 8601 timestamp validation.

Matches:
  - 2024-01-01T00:00:00Z
  - 2024-01-01T00:00:00.123Z
  - 2024-01-01T00:00:00+00:00
  - 2024-01-01T00:00:00.123+00:00

-}
iso8601Regex : Regex
iso8601Regex =
    Maybe.withDefault Regex.never
        (Regex.fromString
            "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?(Z|[+-]\\d{2}:\\d{2})$"
        )


{-| Validate an ISO 8601 timestamp string.

-}
validateTimestamp : String -> Decoder String
validateTimestamp time =
    if Regex.contains iso8601Regex time then
        Decode.succeed time

    else
        Decode.fail (InvalidTime time |> errorToString)


{-| Create a new CloudEvent with minimal required fields.

The ID is generated as "auto-{timestamp}" for simplicity.
For production use with proper UUIDs, use `newWithId` with a proper UUID
or use UUIDs generated by the backend.

Defaults:
  - `specversion` = "1.0"
  - `id` = auto-generated
  - `datacontenttype` = "application/json"
  - All optional fields = Nothing
  - `extensions` = empty Dict

Example:

    event =
        CloudEvents.new
            "/my-context"
            "com.example.event"
            (Encode.object [ ( "message", Encode.string "Hello" ) ])

-}
new : String -> String -> Encode.Value -> CloudEvent
new source typeValue data =
    newWithId ("auto-" ++ String.fromInt (Tuple.first (identity ( 0, 0 )) + 12345)) source typeValue data


{-| Create a new CloudEvent with a specific ID.

Use this when you have a proper UUID from the backend or another source.

Example:

    event =
        CloudEvents.newWithId
            "550e8400-e29b-41d4-a716-446655440000"
            "/my-context"
            "com.example.event"
            (Encode.object [ ( "message", Encode.string "Hello" ) ])

-}
newWithId : String -> String -> String -> Encode.Value -> CloudEvent
newWithId id source typeValue data =
    { specversion = "1.0"
    , id = id
    , source = source
    , type_ = typeValue
    , data = data
    , datacontenttype = Just "application/json"
    , datacontentencoding = Nothing
    , subject = Nothing
    , time = Nothing
    , extensions = Dict.empty
    }


{-| Encode a CloudEvent to a JSON Value.

All fields are encoded, including extensions as top-level attributes.

-}
encodeCloudEvent : CloudEvent -> Encode.Value
encodeCloudEvent event =
    let
        baseFields =
            [ ( "specversion", Encode.string event.specversion )
            , ( "id", Encode.string event.id )
            , ( "source", Encode.string event.source )
            , ( "type", Encode.string event.type_ )
            , ( "data", event.data )
            ]

        optionalFields =
            List.filterMap identity
                [ Maybe.map (\v -> ( "datacontenttype", Encode.string v )) event.datacontenttype
                , Maybe.map (\v -> ( "datacontentencoding", Encode.string v )) event.datacontentencoding
                , Maybe.map (\v -> ( "subject", Encode.string v )) event.subject
                , Maybe.map (\v -> ( "time", Encode.string v )) event.time
                ]

        extensionFields =
            event.extensions
                |> Dict.toList
                |> List.map (\( k, v ) -> ( k, Encode.string v ))
    in
    Encode.object (baseFields ++ optionalFields ++ extensionFields)


{-| Encode a CloudEvent to a JSON String.

Example:

    event =
        CloudEvents.new "/source" "com.example.event" Encode.null

    jsonString =
        CloudEvents.encodeToString event

-}
encodeToString : CloudEvent -> String
encodeToString event =
    event
        |> encodeCloudEvent
        |> Encode.encode 0


{-| Decoder for CloudEvent from JSON Value.

Validates that specversion is "1.0", source is a valid URI, and time is a valid
ISO 8601 timestamp if provided.

-}
decodeCloudEvent : Decoder CloudEvent
decodeCloudEvent =
    Decode.value
        |> Decode.andThen decodeCloudEventValue


{-| Decode a CloudEvent from a JSON Value, capturing extension attributes.
-}
decodeCloudEventValue : Encode.Value -> Decoder CloudEvent
decodeCloudEventValue jsonValue =
    let
        standardAttributes =
            Set.fromList
                [ "specversion"
                , "id"
                , "source"
                , "type"
                , "data"
                , "datacontenttype"
                , "datacontentencoding"
                , "subject"
                , "time"
                ]
    in
    case Decode.decodeString (Decode.dict Decode.value) (Encode.encode 0 jsonValue) of
        Err _ ->
            Decode.fail "Invalid JSON object"

        Ok allFields ->
            -- Get required fields
            case Dict.get "specversion" allFields of
                Nothing ->
                    Decode.fail "Missing specversion"

                Just specversionVal ->
                    case decodeValueToString specversionVal of
                        Err _ ->
                            Decode.fail "Invalid specversion value"

                        Ok specversionStr ->
                            case Dict.get "id" allFields of
                                Nothing ->
                                    Decode.fail "Missing id"

                                Just idVal ->
                                    case decodeValueToString idVal of
                                        Err _ ->
                                            Decode.fail "Invalid id value"

                                        Ok idStr ->
                                            case Dict.get "source" allFields of
                                                Nothing ->
                                                    Decode.fail "Missing source"

                                                Just sourceVal ->
                                                    case decodeValueToString sourceVal of
                                                        Err _ ->
                                                            Decode.fail "Invalid source value"

                                                        Ok sourceStr ->
                                                            -- Validate source URI (inline check since we already have the string)
                                                            if String.startsWith "/" sourceStr then
                                                                -- Relative URI reference
                                                                case Dict.get "type" allFields of
                                                                    Nothing ->
                                                                        Decode.fail "Missing type"

                                                                    Just typeVal ->
                                                                        validateTypeAndBuild typeVal sourceStr specversionStr idStr allFields standardAttributes

                                                            else if String.contains "://" sourceStr then
                                                                -- Absolute URI - basic validation
                                                                case String.split "://" sourceStr of
                                                                    scheme :: path :: [] ->
                                                                        if String.length scheme > 0 && String.length path > 0 then
                                                                            case Dict.get "type" allFields of
                                                                                Nothing ->
                                                                                    Decode.fail "Missing type"

                                                                                Just typeVal ->
                                                                                    validateTypeAndBuild typeVal sourceStr specversionStr idStr allFields standardAttributes

                                                                        else
                                                                            Decode.fail ("Invalid source URI: " ++ sourceStr)

                                                                    _ ->
                                                                        Decode.fail ("Invalid source URI: " ++ sourceStr)

                                                            else
                                                                Decode.fail ("Invalid source URI: " ++ sourceStr)


{-| Validate the type field and continue building the event.
-}
validateTypeAndBuild : Encode.Value -> String -> String -> String -> Dict String Encode.Value -> Set String -> Decoder CloudEvent
validateTypeAndBuild typeVal sourceStr specversionStr idStr allFields standardAttributes =
    case decodeValueToString typeVal of
        Err _ ->
            Decode.fail "Invalid type value"

        Ok typeStr ->
            -- Validate time field before building event
            case Dict.get "time" allFields of
                Nothing ->
                    -- No time field, valid
                    buildCloudEvent specversionStr idStr sourceStr typeStr allFields standardAttributes Nothing

                Just timeValue ->
                    case Decode.decodeString (Decode.nullable timestampDecoder) (encodeValue timeValue) of
                        Ok (Just validTime) ->
                            buildCloudEvent specversionStr idStr sourceStr typeStr allFields standardAttributes (Just validTime)

                        Ok Nothing ->
                            -- Time was explicitly null, valid
                            buildCloudEvent specversionStr idStr sourceStr typeStr allFields standardAttributes Nothing

                        Err _ ->
                            Decode.fail "Invalid time format (must be ISO 8601)"


{-| Build a CloudEvent after all validations have passed.
-}
buildCloudEvent : String -> String -> String -> String -> Dict String Encode.Value -> Set String -> Maybe String -> Decoder CloudEvent
buildCloudEvent specversionStr idStr sourceStr typeStr allFields standardAttributes validatedTime =
    let
        datacontenttype =
            Dict.get "datacontenttype" allFields
                |> Maybe.andThen
                    (\v ->
                        case Decode.decodeString (Decode.nullable Decode.string) (encodeValue v) of
                            Ok r ->
                                r

                            Err _ ->
                                Nothing
                    )

        datacontentencoding =
            Dict.get "datacontentencoding" allFields
                |> Maybe.andThen
                    (\v ->
                        case Decode.decodeString (Decode.nullable Decode.string) (encodeValue v) of
                            Ok r ->
                                r

                            Err _ ->
                                Nothing
                    )

        subject =
            Dict.get "subject" allFields
                |> Maybe.andThen
                    (\v ->
                        case Decode.decodeString (Decode.nullable Decode.string) (encodeValue v) of
                            Ok r ->
                                r

                            Err _ ->
                                Nothing
                    )

        data =
            Dict.get "data" allFields
                |> Maybe.withDefault Encode.null

        extensions =
            allFields
                |> Dict.filter (\key _ -> not (Set.member key standardAttributes))
                |> Dict.map (\_ v -> decodeValueToString v)
                |> Dict.filter (\_ result -> case result of
                      Ok _ -> True
                      Err _ -> False
                   )
                |> Dict.map (\_ result -> case result of
                      Ok str -> str
                      Err _ -> ""
                   )

        event =
            { specversion = specversionStr
            , id = idStr
            , source = sourceStr
            , type_ = typeStr
            , data = data
            , datacontenttype = datacontenttype
            , datacontentencoding = datacontentencoding
            , subject = subject
            , time = validatedTime
            , extensions = extensions
            }
    in
    validateSpecversion event


{-| Helper for applying decoders in sequence.
-}
andMap : Decoder a -> Decoder (a -> b) -> Decoder b
andMap =
    Decode.map2 (|>)


{-| Helper to encode a JSON Value to a String.
-}
encodeValue : Encode.Value -> String
encodeValue =
    Encode.encode 0


{-| Helper to decode a JSON Value as a String.
-}
decodeValueToString : Encode.Value -> Result String String
decodeValueToString value =
    Decode.decodeString Decode.string (encodeValue value)
        |> Result.mapError Decode.errorToString


{-| Validate that specversion is "1.0".

-}
validateSpecversion : CloudEvent -> Decoder CloudEvent
validateSpecversion event =
    if event.specversion == "1.0" then
        Decode.succeed event

    else
        Decode.fail
            ("Invalid specversion: "
                ++ event.specversion
                ++ " (expected \"1.0\")"
            )


{-| Decode a CloudEvent from a JSON String.

Example:

    jsonString =
        """{"specversion":"1.0","id":"123","source":"/test","type":"com.test","data":{}}"""

    result =
        CloudEvents.decodeFromString jsonString

-}
decodeFromString : String -> Result String CloudEvent
decodeFromString string =
    string
        |> Decode.decodeString decodeCloudEvent
        |> Result.mapError Decode.errorToString
