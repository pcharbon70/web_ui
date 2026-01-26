# Section 2.2: JSON Encoding and Decoding

**Feature Branch:** `feature/phase-2.2-json-codecs`
**Status:** COMPLETE
**Created:** 2025-01-26
**Completed:** 2025-01-26

## Objective

Implement JSON serialization and deserialization for CloudEvent structs using Jason.

## Tasks

- [x] 2.2.1 Implement from_json/1 for decoding JSON to struct
- [x] 2.2.2 Implement to_json/1 for encoding struct to JSON
- [x] 2.2.3 Implement from_json_map/1 for decoding from Map
- [x] 2.2.4 Implement to_json_map/1 for encoding to Map
- [x] 2.2.5 Handle specversion validation (must be "1.0")
- [x] 2.2.6 Handle missing required fields with helpful errors
- [x] 2.2.7 Parse ISO 8601 timestamps for time field
- [x] 2.2.8 Encode DateTime to ISO 8601 string
- [x] 2.2.9 Support both "data" and "data_base64" encoding
- [x] 2.2.10 Add error types for parsing failures

## Implementation Notes

- Use Jason for JSON encoding/decoding
- Provide clear error messages for invalid input
- Validate specversion matches supported version
- Handle Unicode correctly in all fields
- Support data_base64 for binary data
- Return {:ok, event} or {:error, reason} tuples
- Also provide from_json!/1 and to_json!/1 that raise

## Unit Tests

- [x] 2.2.1 Test encoding valid CloudEvent to JSON
- [x] 2.2.2 Test decoding valid JSON to CloudEvent
- [x] 2.2.3 Test round-trip encoding/decoding
- [x] 2.2.4 Test error on missing required field
- [x] 2.2.5 Test error on invalid specversion
- [x] 2.2.6 Test timestamp parsing and encoding
- [x] 2.2.7 Test data_base64 encoding/decoding
- [x] 2.2.8 Test error messages are helpful

**Test Results:** 38 JSON tests (all passing)

**Total Project Tests:** 13 doctests + 148 unit tests = 161 tests (all passing)

## Files Created

- `test/web_ui/cloud_event_json_test.exs` - Comprehensive JSON test suite (610 lines)

## Files Modified

- `lib/web_ui/cloud_event.ex` - Added ~320 lines of JSON codec functions

## API Functions Added

### Encoding
- `to_json/1` - Encodes CloudEvent to JSON string (returns tuple)
- `to_json!/1` - Encodes CloudEvent to JSON string (raises on error)
- `to_json_map/1` - Converts CloudEvent to map for JSON encoding

### Decoding
- `from_json/1` - Decodes JSON string to CloudEvent (returns tuple)
- `from_json!/1` - Decodes JSON string to CloudEvent (raises on error)
- `from_json_map/1` - Decodes map to CloudEvent (returns tuple)

### Private Helpers
- `put_data/3` - Sets data or data_base64 field based on encoding
- `encode_time/1` - Converts DateTime to ISO 8601 string
- `decode_time/1` - Parses ISO 8601 string to DateTime
- `decode_data/1` - Handles data vs data_base64 extraction
- `encode_data_base64/1` - Base64 encodes data
- `decode_data_base64/1` - Base64 decodes data
- `validate_required_field/2` - Validates required fields present
- `extract_extensions/1` - Extracts custom attributes from map

## Progress Log

### 2025-01-26 - Initial Setup
- Created feature branch `feature/phase-2.2-json-codecs`
- Created working plan document
- Ready to implement JSON codecs

### 2025-01-26 - Implementation Complete
- Implemented to_json/1, to_json!/1 for JSON encoding
- Implemented from_json/1, from_json!/1 for JSON decoding
- Implemented to_json_map/1, from_json_map/1 for map conversion
- Added specversion validation (must be "1.0")
- Added missing required field validation with helpful errors
- Added ISO 8601 timestamp parsing/encoding
- Added base64 data encoding/decoding support
- Added extension attribute extraction
- Created comprehensive test suite with 38 tests
- All 161 project tests passing

## Questions for Developer

*(None)*

## Next Steps

Write summary to notes/summaries/section-2.2-json-codecs.md
Update main plan document
Ask for permission to commit and merge branch
