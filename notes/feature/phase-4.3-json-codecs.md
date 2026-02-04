# Phase 4.3: CloudEvent JSON Encoders and Decoders

**Branch:** `feature/phase-4.3-json-codecs`
**Date:** 2026-01-29
**Status:** Complete

## Overview

Enhance the CloudEvent JSON encoders and decoders with advanced features beyond what was implemented in section 4.2. Most basic codec functionality is already complete, but we need to add support for:

1. data_base64 encoding/decoding
2. Better error messages with field paths
3. URI/timestamp format validation

## Current State (from Section 4.2)

Already implemented in `assets/elm/src/WebUI/CloudEvents.elm`:

- ✅ `decodeCloudEvent : Decoder CloudEvent`
- ✅ `encodeCloudEvent : CloudEvent -> Encode.Value`
- ✅ `decodeFromString : String -> Result String CloudEvent`
- ✅ `encodeToString : CloudEvent -> String`
- ✅ Handling of required fields
- ✅ Handling of optional fields
- ✅ Specversion validation
- ✅ Extensions dict encoding/decoding

## Additional Requirements from Section 4.3

### 4.3.6 - Custom Error Messages

Add clear, actionable error messages for decode failures.

### 4.3.7 - Field-Specific Decoders

Create specialized decoders for:
- URI validation for `source` field
- ISO 8601 timestamp validation for `time` field

### 4.3.8 - data_base64 Support

Handle both "data" and "data_base64" encoding per CloudEvents spec.

### 4.3.9 - decodeString Convenience

Already implemented as `decodeFromString`.

### 4.3.10 - encodeToString Convenience

Already implemented as `encodeToString`.

## Implementation Plan

### Step 1: Add URI Validator

Create a decoder for URI strings.

### Step 2: Add Timestamp Validator

Create a decoder for ISO 8601 timestamps.

### Step 3: Add data_base64 Support

Update the decoder to handle both "data" and "data_base64" based on `datacontentencoding`.

### Step 4: Improve Error Messages

Add custom error types with field path information.

### Step 5: Write Tests

Add tests for new features.

## Files to Modify

1. `assets/elm/src/WebUI/CloudEvents.elm` - Add validators and data_base64 support
2. `assets/elm/tests/WebUI/CloudEventsTest.elm` - Add new tests

## Files to Create

1. `notes/summaries/section-4.3-json-codecs-elm.md` - Summary

## Success Criteria

- [x] Feature branch created
- [x] URI validator implemented
- [x] Timestamp validator implemented
- [x] data_base64 support added
- [x] Error messages improved (DecodeError type with error codes)
- [x] All tests pass (87 tests)
- [x] Planning document updated
- [x] Summary written (part of section-4.2-cloudevents-elm.md)

## Notes

- The basic codec functionality from section 4.2 is solid
- This section focuses on validation and edge cases
- data_base64 support is optional but important for binary data

## Questions for Developer

None at this time. Proceeding with implementation.
