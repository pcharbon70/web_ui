defmodule WebUi.CloudEventBuildersTest do
  use ExUnit.Case, async: true

  @moduletag :cloudevent_builders

  alias WebUi.CloudEvent

  doctest WebUi.CloudEvent,
    import: [
      put_time: 1,
      put_time: 2,
      put_id: 1,
      put_id: 2,
      put_extension: 3,
      put_subject: 2,
      put_data: 2,
      detect_data_content_type: 1,
      ok: 2,
      error: 2,
      info: 2,
      data_changed: 3
    ]

  describe "put_time/1" do
    test "adds current timestamp to event" do
      event = CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})
      event = CloudEvent.put_time(event)

      assert %DateTime{} = event.time
      assert DateTime.compare(event.time, DateTime.utc_now()) in [:eq, :lt]
    end

    test "returns new event with timestamp" do
      original = CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})
      updated = CloudEvent.put_time(original)

      assert is_nil(original.time)
      refute is_nil(updated.time)
      refute original == updated
    end
  end

  describe "put_time/2" do
    test "sets specific DateTime" do
      event = CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})
      dt = DateTime.from_iso8601("2024-01-15T12:30:45Z") |> elem(1)

      event = CloudEvent.put_time(event, dt)

      assert event.time.year == 2024
      assert event.time.month == 1
      assert event.time.day == 15
    end

    test "sets ISO 8601 string" do
      event = CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})

      event = CloudEvent.put_time(event, "2024-06-15T14:30:45Z")

      assert event.time == "2024-06-15T14:30:45Z"
    end
  end

  describe "put_id/1" do
    test "generates new UUID" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "old-id",
        source: "/test",
        type: "com.test.event",
        data: %{}
      }

      event = CloudEvent.put_id(event)

      assert byte_size(event.id) == 36
      assert event.id != "old-id"
    end

    test "generates unique IDs" do
      event = CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})

      id1 = event.id
      id2 = CloudEvent.put_id(event).id
      id3 = CloudEvent.put_id(event).id

      assert id2 != id1
      assert id3 != id1
      assert id2 != id3
    end
  end

  describe "put_id/2" do
    test "sets specific ID" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "old-id",
        source: "/test",
        type: "com.test.event",
        data: %{}
      }

      event = CloudEvent.put_id(event, "new-custom-id")

      assert event.id == "new-custom-id"
    end
  end

  describe "put_extension/3" do
    test "adds single extension to event without extensions" do
      event = CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})

      event = CloudEvent.put_extension(event, "custom-attr", "custom-value")

      assert event.extensions["custom-attr"] == "custom-value"
    end

    test "merges with existing extensions" do
      event = CloudEvent.new!(
        source: "/test",
        type: "com.test.event",
        data: %{},
        extensions: %{"existing" => "value"}
      )

      event = CloudEvent.put_extension(event, "new-attr", "new-value")

      assert event.extensions["existing"] == "value"
      assert event.extensions["new-attr"] == "new-value"
    end

    test "updates existing extension" do
      event = CloudEvent.new!(
        source: "/test",
        type: "com.test.event",
        data: %{},
        extensions: %{"key" => "old-value"}
      )

      event = CloudEvent.put_extension(event, "key", "new-value")

      assert event.extensions["key"] == "new-value"
      assert map_size(event.extensions) == 1
    end

    test "accepts various value types" do
      event = CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})

      event = CloudEvent.put_extension(event, "string-attr", "string")
      event = CloudEvent.put_extension(event, "number-attr", 42)
      event = CloudEvent.put_extension(event, "bool-attr", true)
      event = CloudEvent.put_extension(event, "nil-attr", nil)

      assert event.extensions["string-attr"] == "string"
      assert event.extensions["number-attr"] == 42
      assert event.extensions["bool-attr"] == true
      assert event.extensions["nil-attr"] == nil
    end
  end

  describe "put_subject/2" do
    test "sets subject on event" do
      event = CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})

      event = CloudEvent.put_subject(event, "my-subject")

      assert event.subject == "my-subject"
    end

    test "updates existing subject" do
      event = CloudEvent.new!(
        source: "/test",
        type: "com.test.event",
        data: %{},
        subject: "old-subject"
      )

      event = CloudEvent.put_subject(event, "new-subject")

      assert event.subject == "new-subject"
    end
  end

  describe "put_data/2" do
    test "updates data field" do
      event = CloudEvent.new!(source: "/test", type: "com.test.event", data: %{old: "data"})

      event = CloudEvent.put_data(event, %{new: "data"})

      assert event.data == %{new: "data"}
    end

    test "accepts various data types" do
      event = CloudEvent.new!(source: "/test", type: "com.test.event", data: nil)

      event = CloudEvent.put_data(event, [1, 2, 3])
      assert event.data == [1, 2, 3]

      event = CloudEvent.put_data(event, "string data")
      assert event.data == "string data"

      event = CloudEvent.put_data(event, 42)
      assert event.data == 42
    end
  end

  describe "detect_data_content_type/1" do
    test "returns application/json for maps" do
      assert CloudEvent.detect_data_content_type(%{key: "value"}) == "application/json"
      assert CloudEvent.detect_data_content_type(%{}) == "application/json"
    end

    test "returns application/json for lists" do
      assert CloudEvent.detect_data_content_type([1, 2, 3]) == "application/json"
      assert CloudEvent.detect_data_content_type([]) == "application/json"
    end

    test "returns text/plain for strings" do
      assert CloudEvent.detect_data_content_type("plain text") == "text/plain"
      assert CloudEvent.detect_data_content_type("") == "text/plain"
    end

    test "returns application/json for numbers" do
      assert CloudEvent.detect_data_content_type(42) == "application/json"
      assert CloudEvent.detect_data_content_type(3.14) == "application/json"
    end

    test "returns application/json for booleans" do
      assert CloudEvent.detect_data_content_type(true) == "application/json"
      assert CloudEvent.detect_data_content_type(false) == "application/json"
    end

    test "returns application/json for nil" do
      assert CloudEvent.detect_data_content_type(nil) == "application/json"
    end
  end

  describe "ok/2" do
    test "creates success event" do
      event = CloudEvent.ok("my-operation", %{result: "success"})

      assert event.type == "com.ok.my-operation"
      assert event.source == "urn:ok:my-operation"
      assert event.data == %{result: "success"}
      assert %DateTime{} = event.time
    end

    test "includes timestamp" do
      event = CloudEvent.ok("test", %{})

      assert %DateTime{} = event.time
    end
  end

  describe "error/2" do
    test "creates error event" do
      event = CloudEvent.error("validation", %{errors: ["invalid input"]})

      assert event.type == "com.error.validation"
      assert event.source == "urn:error:validation"
      assert event.data == %{errors: ["invalid input"]}
      assert %DateTime{} = event.time
    end
  end

  describe "info/2" do
    test "creates info event" do
      event = CloudEvent.info("debug", %{message: "processing started"})

      assert event.type == "com.info.debug"
      assert event.source == "urn:info:debug"
      assert event.data == %{message: "processing started"}
      assert %DateTime{} = event.time
    end
  end

  describe "data_changed/3" do
    test "creates data changed event" do
      event = CloudEvent.data_changed("user", "123", %{status: "active"})

      assert event.type == "com.data_changed.user"
      assert event.source == "urn:data_changed:user"
      assert event.subject == "123"
      assert event.data == %{status: "active"}
      assert %DateTime{} = event.time
    end

    test "sets subject to entity_id" do
      event = CloudEvent.data_changed("product", "abc-456", %{price: 10.0})

      assert event.subject == "abc-456"
    end
  end

  describe "__using__/1" do
    test "macro is defined and can be used" do
      # The __using__ macro exists and can be referenced
      # We verify this by checking the module has the macro
      assert function_exported?(WebUi.CloudEvent, :__using__, 1)
    end
  end

  describe "pipelining" do
    test "can chain put operations" do
      event =
        CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})
        |> CloudEvent.put_time()
        |> CloudEvent.put_subject("test-subject")
        |> CloudEvent.put_extension("custom", "value")

      assert %DateTime{} = event.time
      assert event.subject == "test-subject"
      assert event.extensions["custom"] == "value"
    end

    test "put operations return new struct" do
      original = CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})

      updated =
        original
        |> CloudEvent.put_time()
        |> CloudEvent.put_id()
        |> CloudEvent.put_subject("subject")

      # Original is unchanged
      assert original.time == nil
      assert original.subject == nil

      # Updated has changes
      assert updated.time != nil
      assert updated.subject == "subject"
      assert updated.id != original.id
    end
  end

  describe "round-trip with builder functions" do
    test "event built with put functions can be serialized" do
      event =
        CloudEvent.new!(source: "/test", type: "com.test.event", data: %{message: "Hello"})
        |> CloudEvent.put_time()
        |> CloudEvent.put_extension("custom", "value")

      assert {:ok, json} = CloudEvent.to_json(event)
      assert {:ok, decoded} = CloudEvent.from_json(json)

      assert decoded.source == event.source
      assert decoded.type == event.type
      assert decoded.extensions["custom"] == "value"
    end
  end
end
