# Phase 4.2: CloudEvents Elm Module

**Branch:** `feature/phase-4.2-cloudevents-elm`
**Date:** 2026-01-29
**Status:** In Progress

## Overview

Implement the WebUI.CloudEvents Elm module with CloudEvent type definition and JSON codecs, matching the Elixir implementation for full interoperability.

## Elixir CloudEvent Structure (Reference)

From `lib/web_ui/cloud_event.ex`:

```elixir
@struct_fields [
  :specversion,          # Required: String (always "1.0")
  :id,                   # Required: String (UUID)
  :source,               # Required: String (URI reference)
  :type,                 # Required: String (event type)
  :data,                 # Required: Any JSON value
  :datacontenttype,      # Optional: String (default "application/json")
  :datacontentencoding,  # Optional: String (e.g., "base64")
  :subject,              # Optional: String
  :time,                 # Optional: String (ISO 8601)
  :extensions            # Optional: Dict String String
]
```

## Implementation Plan

### Step 1: Create WebUI.CloudEvents Module

**File:** `assets/elm/src/WebUI/CloudEvents.elm`

Define the CloudEvent type alias matching the Elixir struct:

```elm
type alias CloudEvent =
    { specversion : String           -- Always "1.0"
    , id : String                    -- Unique identifier (UUID)
    , source : String                -- URI reference
    , type_ : String                 -- Event type (type_ reserved word)
    , data : Json.Encode.Value       -- Event data
    , datacontenttype : Maybe String -- Content type
    , datacontentencoding : Maybe String -- Encoding (base64)
    , subject : Maybe String         -- Subject of event
    , time : Maybe String            -- ISO 8601 timestamp
    , extensions : Dict String String -- Custom attributes
    }
```

### Step 2: Implement JSON Encoder

Create `encodeCloudEvent : CloudEvent -> Json.Encode.Value` function:

- Map all fields to JSON
- Use `type` as the JSON key (not `type_`)
- Handle Maybe fields appropriately
- Include extensions as top-level attributes

### Step 3: Implement JSON Decoder

Create `decodeCloudEvent : Json.Decode.Decoder CloudEvent` function:

- Use Json.Decode.Pipeline for readable decoding
- Validate specversion is "1.0"
- Handle all required fields
- Handle optional fields with Maybe
- Decode extensions dict

### Step 4: Add Helper Functions

Create convenience functions:

- `new : String -> String -> Json.Encode.Value -> CloudEvent` (source, type, data)
- `encodeToString : CloudEvent -> String`
- `decodeFromString : String -> Result String CloudEvent`

### Step 5: Write Tests

**File:** `assets/elm/tests/WebUI/CloudEventsTest.elm`

Test cases:
1. CloudEvent type creates valid record
2. Encoder produces valid JSON
3. Decoder parses valid JSON
4. Round-trip encode/decode preserves data
5. Decoder fails on missing required field
6. Decoder handles optional fields
7. Decoder validates specversion is "1.0"
8. Extensions are preserved

## Files to Create

1. `assets/elm/src/WebUI/CloudEvents.elm` - Main module
2. `assets/elm/tests/WebUI/CloudEventsTest.elm` - Tests

## Files to Modify

1. `notes/planning/poc/phase-4-elm-frontend.md` - Mark tasks complete

## Dependencies

- `elm/core` - Basics, Dict, Maybe
- `elm/json` - Json.Encode, Json.Decode, Json.Decode.Pipeline

## Success Criteria

- [x] Feature branch created
- [ ] CloudEvents.elm module created with type definition
- [ ] JSON encoder implemented
- [ ] JSON decoder implemented
- [ ] All tests pass
- [ ] Planning document updated
- [ ] Summary written

## Notes

- `type` is a reserved word in Elm, so use `type_` in the record but `type` in JSON
- Use Json.Decode.Pipeline for clean decoder definition
- Extensions should be merged as top-level JSON attributes per CloudEvents spec
- All timestamp strings should be ISO 8601 format

## Questions for Developer

None at this time. Proceeding with implementation.
