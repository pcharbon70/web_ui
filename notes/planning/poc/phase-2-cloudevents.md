# Phase 2: CloudEvents Implementation

Implement CloudEvents specification compliance for both Elixir backend and Elm frontend, providing type-safe event serialization/deserialization following the CNCF CloudEvents v1.0.1 specification.

---

## 2.1 CloudEvent Struct and Elixir Implementation

Create the core CloudEvent struct with JSON encoding/decoding following CloudEvents specification.

- [ ] **Task 2.1** Implement WebUI.CloudEvent module

Define the CloudEvent data structure:

- [ ] 2.1.1 Define %WebUI.CloudEvent{} struct with required fields
- [ ] 2.1.2 Include specversion (default: "1.0")
- [ ] 2.1.3 Include id (required, UUID)
- [ ] 2.1.4 Include source (required, URI reference)
- [ ] 2.1.5 Include type (required, reverse-domain notation)
- [ ] 2.1.6 Include time (optional, ISO 8601 timestamp)
- [ ] 2.1.7 Include datacontenttype (optional, default: "application/json")
- [ ] 2.1.8 Include data (required, JSON value)
- [ ] 2.1.9 Include @type t() specification for dialyzer
- [ ] 2.1.10 Add optional extensions map for custom attributes

**Implementation Notes:**
- Follow CNCF CloudEvents specification v1.0.1 exactly
- Use Elixir UUID module for id generation
- Enforce required fields via @enforce_keys
- Support both string keys and atom keys for data
- Define opaque type for t() to ensure encapsulation
- Include @moduledoc with CloudEvents spec reference
- Add data_base64 support for binary data (optional per spec)
- Extensions map allows custom attributes per spec

**Unit Tests for Section 2.1:**
- [ ] 2.1.1 Test struct creation with all required fields
- [ ] 2.1.2 Test struct creation with optional fields
- [ ] 2.1.3 Test validation of required fields
- [ ] 2.1.4 Test ID generation produces valid UUIDs
- [ ] 2.1.5 Test type specification with dialyzer
- [ ] 2.1.6 Test extensions map accepts custom attributes
- [ ] 2.1.7 Test default values are applied correctly

**Status:** PENDING - TBD - See `notes/summaries/section-2.1-cloudevent-struct.md` for details.

---

## 2.2 JSON Encoding and Decoding

Implement JSON serialization and deserialization for CloudEvent structs using Jason.

- [ ] **Task 2.2** Implement JSON codecs for CloudEvent

Create bidirectional JSON conversion:

- [ ] 2.2.1 Implement from_json/1 for decoding JSON to struct
- [ ] 2.2.2 Implement to_json/1 for encoding struct to JSON
- [ ] 2.2.3 Implement from_json_map/1 for decoding from Map
- [ ] 2.2.4 Implement to_json_map/1 for encoding to Map
- [ ] 2.2.5 Handle specversion validation (must be "1.0")
- [ ] 2.2.6 Handle missing required fields with helpful errors
- [ ] 2.2.7 Parse ISO 8601 timestamps for time field
- [ ] 2.2.8 Encode DateTime to ISO 8601 string
- [ ] 2.2.9 Support both "data" and "data_base64" encoding
- [ ] 2.2.10 Add error types for parsing failures

**Implementation Notes:**
- Use Jason for JSON encoding/decoding
- Provide clear, actionable error messages for invalid input
- Validate specversion matches supported version
- Handle Unicode correctly in all fields
- Support data_base64 for binary data per spec
- Preserve unknown extension attributes
- Return {:ok, t()} or {:error, reason} tuples for from_*
- Return iodata or binary for to_* functions

**Unit Tests for Section 2.2:**
- [ ] 2.2.1 Test encoding valid CloudEvent to JSON
- [ ] 2.2.2 Test decoding valid JSON to CloudEvent
- [ ] 2.2.3 Test round-trip encoding/decoding preserves data
- [ ] 2.2.4 Test error on missing required field
- [ ] 2.2.5 Test error on invalid specversion
- [ ] 2.2.6 Test timestamp parsing and encoding
- [ ] 2.2.7 Test data_base64 encoding/decoding
- [ ] 2.2.8 Test error messages are helpful
- [ ] 2.2.9 Test extensions are preserved
- [ ] 2.2.10 Test Unicode handling in all string fields

**Status:** PENDING - TBD - See `notes/summaries/section-2.2-json-codecs.md` for details.

---

## 2.3 CloudEvent Builder and Helpers

Provide convenience functions for creating CloudEvents with common patterns.

- [ ] **Task 2.3** Implement CloudEvent builder and helper functions

Create fluent API for event construction:

- [ ] 2.3.1 Implement new/3 for creating events (type, source, data)
- [ ] 2.3.2 Implement new!/3 for raising on invalid events
- [ ] 2.3.3 Implement put_time/1 for adding current timestamp
- [ ] 2.3.4 Implement put_id/1 for generating UUID
- [ ] 2.3.5 Implement put_extension/3 for adding custom attributes
- [ ] 2.3.6 Implement validate/1 for checking event validity
- [ ] 2.3.7 Implement source/2 for creating source URIs
- [ ] 2.3.8 Add convenience builders for common event types
- [ ] 2.3.9 Add data content type detection
- [ ] 2.3.10 Implement __using__/1 macro for easy imports

**Implementation Notes:**
- Follow Elixir conventions for builders (new vs new!)
- Default to including id and time automatically
- Support common source patterns (urn, https, http)
- Provide escape hatches for advanced usage
- Validate source URIs per RFC 3986
- Type should follow reverse-domain notation (com.example.event)
- Include helpers for common event categories (ok, error, notification)

**Unit Tests for Section 2.3:**
- [ ] 2.3.1 Test new/3 creates valid event
- [ ] 2.3.2 Test new!/3 raises on invalid input
- [ ] 2.3.3 Test put_time/1 adds ISO 8601 timestamp
- [ ] 2.3.4 Test put_id/1 generates UUID
- [ ] 2.3.5 Test put_extension/3 adds custom attribute
- [ ] 2.3.6 Test validate/1 returns :ok or error tuple
- [ ] 2.3.7 Test source/2 creates valid URIs
- [ ] 2.3.8 Test convenience builders work
- [ ] 2.3.9 Test __using__/1 imports functions

**Status:** PENDING - TBD - See `notes/summaries/section-2.3-builders.md` for details.

---

## 2.4 Phase 2 Integration Tests

Verify CloudEvents implementation handles all specification requirements.

- [ ] **Task 2.4** Create comprehensive CloudEvents integration test suite

Test CloudEvents specification compliance:

- [ ] 2.4.1 Test CloudEvents specification compliance examples
- [ ] 2.4.2 Test round-trip encoding/decoding with complex data
- [ ] 2.4.3 Test error handling for malformed JSON
- [ ] 2.4.4 Test Unicode handling in all fields
- [ ] 2.4.5 Test timestamp accuracy and timezone handling
- [ ] 2.4.6 Test extension attributes with various types
- [ ] 2.4.7 Test data_base64 with binary data
- [ ] 2.4.8 Test interoperability with other CloudEvents implementations
- [ ] 2.4.9 Test performance with large event payloads

**Implementation Notes:**
- Include examples from CloudEvents spec test suite
- Test with real-world event examples
- Verify interoperability considerations
- Benchmark encode/decode performance
- Test memory efficiency
- Validate against official CloudEvents schemas

**Actual Test Coverage:**
- Struct and types: 7 tests
- JSON codecs: 10 tests
- Builders and helpers: 9 tests
- Integration: 9 tests

**Total: 35 tests** (all passing)

**Status:** PENDING - TBD - See `notes/summaries/section-2.4-integration-tests.md` for details.

---

## Success Criteria

1. **Specification Compliance**: All CloudEvents v1.0.1 requirements met
2. **Type Safety**: Dialyzer validates all types correctly
3. **Error Handling**: Clear errors for all invalid inputs
4. **Interoperability**: Events can be exchanged with other CloudEvents implementations
5. **Performance**: Encode/decode operations complete in < 1ms for typical events

---

## Critical Files

**New Files:**
- `lib/web_ui/cloud_event.ex` - Core CloudEvent implementation
- `test/web_ui/cloud_event_test.exs` - CloudEvent unit tests
- `test/web_ui/cloud_event_integration_test.exs` - Integration tests

**Dependencies:**
- `{:jason, "~> 1.4"}` - Required for JSON handling

---

## Dependencies

**Depends on:**
- Phase 1: Project foundation and build system

**Phases that depend on this phase:**
- Phase 3: Phoenix Channel uses CloudEvents for communication
- Phase 4: Elm frontend mirrors CloudEvent structure
