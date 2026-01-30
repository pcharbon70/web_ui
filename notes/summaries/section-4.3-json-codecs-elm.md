# Section 4.3: CloudEvent JSON Encoders and Decoders - Summary

**Branch:** `feature/phase-4.3-json-codecs`
**Date:** 2026-01-29
**Status:** Complete

## Overview

Enhanced the CloudEvent JSON encoders and decoders with advanced validation features and better error messages. The basic codec functionality from section 4.2 was solid; this section added field-specific validators and improved error reporting.

## What Was Added

### 1. DecodeError Type

A custom error type for better error messages:

```elm
type DecodeError
    = InvalidSpecversion String
    | InvalidSource String
    | InvalidTime String
    | MissingRequiredField String
    | JsonError String
```

### 2. URI Validation

Added `uriDecoder` for validating the `source` field:
- Accepts relative URI references (starting with `/`)
- Accepts absolute URIs with scheme (e.g., `https://example.com/path`)
- Rejects malformed URIs

### 3. Timestamp Validation

Added `timestampDecoder` for validating the `time` field:
- Validates ISO 8601 format
- Accepts UTC timestamps with `Z` suffix
- Accepts milliseconds: `2024-01-01T00:00:00.123Z`
- Accepts timezone offsets: `2024-01-01T00:00:00+00:00`
- Rejects invalid formats

### 4. Error Messages

Improved error messages with field context:
- `InvalidSpecversion` - explains expected "1.0"
- `InvalidSource` - explains URI requirement
- `InvalidTime` - explains ISO 8601 format

## API Additions

### New Exported Types

- `DecodeError` - Custom error type for decode failures

### New Internal Functions

- `uriDecoder : Decoder String` - URI reference decoder
- `validateUri : String -> Decoder String` - URI validation logic
- `timestampDecoder : Decoder String` - ISO 8601 timestamp decoder
- `validateTimestamp : String -> Decoder String` - Timestamp validation logic
- `iso8601Regex : Regex` - ISO 8601 pattern matcher

## Modified Functions

- `decodeCloudEvent` - Now uses `uriDecoder` for source and `timestampDecoder` for time

## Tests Added

10 new tests in the "4.3 - Field Validation" describe block:

**URI Validation (3 tests):**
- Accepts relative URI starting with /
- Accepts absolute URI with scheme
- Rejects invalid source URI

**Timestamp Validation (4 tests):**
- Accepts valid ISO 8601 timestamp with Z
- Accepts valid ISO 8601 timestamp with milliseconds
- Accepts valid ISO 8601 timestamp with timezone offset
- Rejects invalid timestamp format

**Error Messages (3 tests):**
- Error message includes field information for invalid specversion
- Error message includes field information for invalid source
- Error message includes field information for invalid time

## Files Modified

1. `assets/elm/src/WebUI/CloudEvents.elm` - Added validators and DecodeError type
2. `assets/elm/tests/WebUI/CloudEventsTest.elm` - Added 10 new tests

## Files Created

1. `notes/feature/phase-4.3-json-codecs.md` - Working plan
2. `notes/summaries/section-4.3-json-codecs-elm.md` - Summary

## Dependencies

- `elm/core` - Basics, Dict, Maybe, Regex, String
- `elm/json` - Json.Encode, Json.Decode, Json.Decode.Pipeline

## Deferred Items

The following items from the original plan were deferred as not commonly needed:

- **data_base64 support** - Base64 encoding for binary data. This is rarely used in practice and can be added later if needed.

## Breaking Changes

None. All changes are additive and backward compatible. The existing API remains unchanged.

## Validation Rules

### Source (URI Reference)

**Valid:**
- `/my-context` (relative URI reference)
- `https://example.com/context` (absolute URI)
- `urn:example:event` (URN)

**Invalid:**
- `not-a-uri` (no scheme or leading /)
- `://` (empty scheme)
- `https://` (empty path)

### Time (ISO 8601)

**Valid:**
- `2024-01-01T00:00:00Z`
- `2024-01-01T00:00:00.123Z`
- `2024-01-01T00:00:00+00:00`
- `2024-01-01T00:00:00.123+05:30`

**Invalid:**
- `2024-01-01 00:00:00` (space instead of T)
- `2024-01-01` (date only)
- `invalid-time` (not ISO 8601)

## Next Steps

Section 4.4: Elm Ports for JavaScript Interop
- Create WebUI.Ports module
- Define ports for WebSocket communication
- Define ports for JavaScript interop

## Running Tests

```bash
# Run Elm tests
npm run test:elm
# or
elm-test
```

Note: Tests require `elm` and `elm-test` to be installed.
