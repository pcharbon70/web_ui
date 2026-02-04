# Section 2.3: CloudEvent Builder and Helper Functions

**Feature Branch:** `feature/phase-2.3-builders`
**Status:** COMPLETE
**Created:** 2025-01-26
**Completed:** 2025-01-26

## Objective

Implement convenience builder and helper functions for creating CloudEvents with common patterns. These functions will make it easier to work with CloudEvents by providing setter functions, convenience builders, and automatic field population.

## Tasks

- [x] 2.3.1 Implement put_time/1 for adding current timestamp
- [x] 2.3.2 Implement put_time/2 for setting specific timestamp
- [x] 2.3.3 Implement put_id/1 for generating UUID
- [x] 2.3.4 Implement put_id/2 for setting specific ID
- [x] 2.3.5 Implement put_extension/3 for adding custom attributes
- [x] 2.3.6 Implement put_subject/2 for setting subject
- [x] 2.3.7 Implement put_data/2 for updating data
- [x] 2.3.8 Implement convenience builders for common event types
- [x] 2.3.9 Add data content type detection
- [x] 2.3.10 Add __using__/1 macro for easy imports

## Implementation Notes

### Setter Functions (put_*)
These functions take a CloudEvent struct and return a modified struct:

- `put_time/1` - Adds current UTC timestamp
- `put_time/2` - Sets specific DateTime or ISO 8601 string
- `put_id/1` - Generates and sets UUID v4
- `put_id/2` - Sets specific ID string
- `put_extension/3` - Adds/updates a custom attribute in extensions
- `put_subject/2` - Sets the subject field
- `put_data/2` - Updates the data field

These are designed for pipelining: `event |> put_id() |> put_time() |> put_extension("key", "value")`

### Convenience Builders
Functions for quickly creating common event types:

- `ok/2` - Creates a success event
- `error/2` - Creates an error event
- `info/2` - Creates an info event
- `data_changed/3` - Creates a state change event

### Content Type Detection
- `detect_data_content_type/1` - Analyzes data and suggests MIME type

### Using Macro
- `__using__/1` - Automatically imports common functions when `use WebUi.CloudEvent` is called

## Unit Tests

- [x] 2.3.1 Test put_time/1 adds current timestamp
- [x] 2.3.2 Test put_time/2 sets specific timestamp
- [x] 2.3.3 Test put_id/1 generates UUID
- [x] 2.3.4 Test put_id/2 sets specific ID
- [x] 2.3.5 Test put_extension/3 adds custom attribute
- [x] 2.3.6 Test put_extension/3 merges with existing extensions
- [x] 2.3.7 Test put_subject/2 sets subject
- [x] 2.3.8 Test put_data/2 updates data
- [x] 2.3.9 Test ok/2 creates success event
- [x] 2.3.10 Test error/2 creates error event
- [x] 2.3.11 Test info/2 creates info event
- [x] 2.3.12 Test data_changed/3 creates state change event
- [x] 2.3.13 Test detect_data_content_type/1 detects types correctly
- [x] 2.3.14 Test __using__/1 imports functions

**Test Results:** 31 builder tests + 32 doctests = 63 tests (all passing)

**Total Project Tests:** 65 doctests + 177 unit tests = 242 tests (all passing)

## Files Created

- `test/web_ui/cloud_event_builders_test.exs` - Builder function tests (370+ lines)

## Files Modified

- `lib/web_ui/cloud_event.ex` - Added ~320 lines of builder functions

## API Functions Added

### Setter Functions
- `put_time/1` - Adds current UTC timestamp to event
- `put_time/2` - Sets specific DateTime or ISO 8601 string
- `put_id/1` - Generates and sets new UUID
- `put_id/2` - Sets specific ID string
- `put_extension/3` - Adds/updates extension attribute
- `put_subject/2` - Sets subject field
- `put_data/2` - Updates data field

### Convenience Builders
- `ok/2` - Creates success event (type: "com.ok.{name}")
- `error/2` - Creates error event (type: "com.error.{name}")
- `info/2` - Creates info event (type: "com.info.{name}")
- `data_changed/3` - Creates data changed event (type: "com.data_changed.{entity_type}")

### Utilities
- `detect_data_content_type/1` - Detects MIME type from data structure
- `__using__/1` - Macro for importing common functions

## Progress Log

### 2025-01-26 - Initial Setup
- Created feature branch `feature/phase-2.3-builders`
- Created working plan document
- Ready to implement builder functions

### 2025-01-26 - Implementation Complete
- Implemented all put_* setter functions
- Implemented convenience builders (ok, error, info, data_changed)
- Implemented detect_data_content_type/1
- Implemented __using__/1 macro
- Created comprehensive test suite with 63 tests
- All 242 project tests passing

## Questions for Developer

*(None)*

## Next Steps

Write summary to notes/summaries/section-2.3-builders.md
Update main plan document
Ask for permission to commit and merge branch
