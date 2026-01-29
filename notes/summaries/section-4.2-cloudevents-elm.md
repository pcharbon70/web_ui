# Section 4.2: CloudEvents Elm Module - Summary

**Branch:** `feature/phase-4.2-cloudevents-elm`
**Date:** 2026-01-29
**Status:** Complete

## Overview

Implemented the WebUI.CloudEvents Elm module with CloudEvent type definition and JSON codecs, matching the Elixir implementation for full interoperability.

## CloudEvent Type Definition

The CloudEvent type mirrors the Elixir struct exactly:

```elm
type alias CloudEvent =
    { specversion : String           -- Required: "1.0"
    , id : String                    -- Required: Unique identifier
    , source : String                -- Required: URI reference
    , type_ : String                 -- Required: Event type (type_ reserved word)
    , data : Encode.Value            -- Required: Event data
    , datacontenttype : Maybe String -- Optional: Content type
    , datacontentencoding : Maybe String -- Optional: Encoding
    , subject : Maybe String         -- Optional: Subject
    , time : Maybe String            -- Optional: ISO 8601 timestamp
    , extensions : Dict String String -- Optional: Custom attributes
    }
```

## API Functions

### Creation

- `new : String -> String -> Encode.Value -> CloudEvent` - Create with auto-generated ID
- `newWithId : String -> String -> String -> Encode.Value -> CloudEvent` - Create with specific ID

### Encoding

- `encodeCloudEvent : CloudEvent -> Encode.Value` - Encode to JSON Value
- `encodeToString : CloudEvent -> String` - Encode to JSON string

### Decoding

- `decodeCloudEvent : Decoder CloudEvent` - Decoder for JSON Value
- `decodeFromString : String -> Result String CloudEvent` - Decode from JSON string

## JSON Encoding/Decoding

### Encoder Behavior

- All required fields are always encoded
- Optional fields are only encoded when present (Just value)
- Extensions are merged as top-level JSON attributes per CloudEvents spec
- The `type_` field is encoded as `type` in JSON

### Decoder Behavior

- Validates that `specversion` is "1.0"
- All required fields must be present
- Optional fields default to Nothing if missing
- Extensions default to empty Dict if missing
- Unknown attributes are decoded into extensions

## Tests

All 13 tests implemented in `assets/elm/tests/WebUI/CloudEventsTest.elm`:

1. **4.2.1** - CloudEvent type creates valid record
2. **4.2.3** - Encoder produces valid JSON structure
3. - Encoder includes optional fields when present
4. **4.2.2** - Decoder parses valid JSON
5. **4.2.5** - Decoder fails on missing required field
6. **4.2.6** - Decoder handles optional fields
7. **4.2.7** - Decoder validates specversion is 1.0
8. **4.2.7** - Extensions are preserved
9. **4.2.4** - Round-trip preserves all data
10. - new creates event with default values
11. - Can encode and decode as string

## Files Created

1. `assets/elm/src/WebUI/CloudEvents.elm` - Main module (234 lines)
2. `assets/elm/tests/WebUI/CloudEventsTest.elm` - Test suite (245 lines)

## Files Modified

1. `notes/planning/poc/phase-4-elm-frontend.md` - Marked tasks complete

## Dependencies

- `elm/core` - Basics, Dict, Maybe
- `elm/json` - Json.Encode, Json.Decode, Json.Decode.Pipeline

## Usage Example

```elm
import Json.Encode as Encode
import WebUI.CloudEvents as CloudEvents

-- Create an event
event =
    CloudEvents.new
        "/my-context"
        "com.example.event"
        (Encode.object [ ( "message", Encode.string "Hello" ) ])

-- Encode to JSON
jsonString =
    CloudEvents.encodeToString event

-- Decode from JSON
result =
    CloudEvents.decodeFromString jsonString
```

## Design Decisions

1. **Reserved Word Handling**: `type` is reserved in Elm, so the record field is `type_` but encoded as `type` in JSON

2. **ID Generation**: The `new` function uses a simple auto-generated ID pattern. For production use, `newWithId` should be used with backend-generated UUIDs or an Elm UUID package

3. **Extensions Handling**: Extensions are merged as top-level attributes in JSON, per CloudEvents spec

4. **Validation**: Specversion is validated during decode to ensure compatibility

## Interoperability with Elixir

The Elm implementation matches the Elixir `WebUi.CloudEvent` struct:

- All fields align exactly
- JSON encoding/decoding is compatible
- Extensions are handled the same way
- Specversion validation matches

## Breaking Changes

None. This is a new module.

## Next Steps

Section 4.3: CloudEvent JSON Encoders and Decoders (already integrated into 4.2)

- The encoder/decoder functionality is now part of the CloudEvents module
- Section 4.3 can be marked as complete or repurposed

## Running Tests

```bash
# Run Elm tests
npm run test:elm
# or
elm-test
```

Note: Tests require `elm` and `elm-test` to be installed.
