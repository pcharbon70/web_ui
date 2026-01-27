defmodule WebUi.CloudEventIntegrationTest do
  use ExUnit.Case, async: true

  @moduletag :cloudevent_integration

  alias WebUi.CloudEvent

  describe "CloudEvents specification compliance" do
    test "parses official CloudEvents JSON example (GitHub pull request)" do
      # Example from CloudEvents spec v1.0.1
      json = ~s({
        "specversion": "1.0",
        "type": "com.github.pull_request.opened",
        "source": "https://github.com/cloudevents/spec/pull",
        "id": "A234-1234-1234",
        "datacontenttype": "application/json",
        "data": {
          "pullrequest": {
            "id": 123,
            "title": "Implement CloudEvents",
            "state": "open"
          }
        }
      })

      assert {:ok, event} = CloudEvent.from_json(json)
      assert event.specversion == "1.0"
      assert event.type == "com.github.pull_request.opened"
      assert event.source == "https://github.com/cloudevents/spec/pull"
      assert event.id == "A234-1234-1234"
      assert event.datacontenttype == "application/json"
      assert event.data["pullrequest"]["id"] == 123
    end

    test "parses minimal CloudEvents example" do
      # Minimal valid event
      json = ~s({"specversion":"1.0","id":"test","source":"/test","type":"com.test","data":{}})

      assert {:ok, event} = CloudEvent.from_json(json)
      assert event.specversion == "1.0"
      assert event.id == "test"
      assert event.source == "/test"
      assert event.type == "com.test"
    end

    test "parses CloudEvents with all optional attributes" do
      json = ~s({
        "specversion": "1.0",
        "id": "test-id",
        "source": "/my-context",
        "type": "com.example.event",
        "datacontenttype": "application/json",
        "datacontentencoding": "base64",
        "subject": "my-subject",
        "time": "2024-01-15T12:30:45Z",
        "data": {"key": "value"}
      })

      assert {:ok, event} = CloudEvent.from_json(json)
      assert event.datacontenttype == "application/json"
      assert event.datacontentencoding == "base64"
      assert event.subject == "my-subject"
      assert %DateTime{} = event.time
    end
  end

  describe "complex data structures" do
    test "round-trips nested maps" do
      data = %{
        "user" => %{
          "id" => "123",
          "profile" => %{
            "name" => "Test User",
            "preferences" => %{
              "theme" => "dark",
              "language" => "en"
            }
          }
        }
      }

      original = CloudEvent.new!(source: "/test", type: "com.test.event", data: data)
      assert {:ok, json} = CloudEvent.to_json(original)
      assert {:ok, decoded} = CloudEvent.from_json(json)

      assert decoded.data["user"]["id"] == "123"
      assert decoded.data["user"]["profile"]["name"] == "Test User"
      assert decoded.data["user"]["profile"]["preferences"]["theme"] == "dark"
    end

    test "round-trips arrays of mixed types" do
      data = [
        %{"name" => "item1", "value" => 100},
        %{"name" => "item2", "value" => 200},
        %{"name" => "item3", "value" => 300}
      ]

      original = CloudEvent.new!(source: "/test", type: "com.test.event", data: data)
      assert {:ok, json} = CloudEvent.to_json(original)
      assert {:ok, decoded} = CloudEvent.from_json(json)

      assert length(decoded.data) == 3
      assert Enum.at(decoded.data, 0)["name"] == "item1"
      assert Enum.at(decoded.data, 2)["value"] == 300
    end

    test "round-trips deeply nested structures" do
      data = %{
        "level1" => %{
          "level2" => %{
            "level3" => %{
              "level4" => %{
                "level5" => "deep value"
              }
            }
          }
        }
      }

      original = CloudEvent.new!(source: "/test", type: "com.test.event", data: data)
      assert {:ok, json} = CloudEvent.to_json(original)
      assert {:ok, decoded} = CloudEvent.from_json(json)

      assert decoded.data["level1"]["level2"]["level3"]["level4"]["level5"] == "deep value"
    end

    test "round-trips arrays with various types" do
      data = [
        "string",
        123,
        45.67,
        true,
        false,
        nil,
        %{"nested" => "map"},
        [1, 2, 3]
      ]

      original = CloudEvent.new!(source: "/test", type: "com.test.event", data: data)
      assert {:ok, json} = CloudEvent.to_json(original)
      assert {:ok, decoded} = CloudEvent.from_json(json)

      assert Enum.at(decoded.data, 0) == "string"
      assert Enum.at(decoded.data, 1) == 123
      assert Enum.at(decoded.data, 2) == 45.67
      assert Enum.at(decoded.data, 3) == true
      assert Enum.at(decoded.data, 4) == false
      assert Enum.at(decoded.data, 5) == nil
      assert Enum.at(decoded.data, 6)["nested"] == "map"
      assert Enum.at(decoded.data, 7) == [1, 2, 3]
    end

    test "round-trips empty containers" do
      # Empty map
      event1 = CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})
      assert {:ok, json1} = CloudEvent.to_json(event1)
      assert {:ok, decoded1} = CloudEvent.from_json(json1)
      assert decoded1.data == %{}

      # Empty list
      event2 = CloudEvent.new!(source: "/test", type: "com.test.event", data: [])
      assert {:ok, json2} = CloudEvent.to_json(event2)
      assert {:ok, decoded2} = CloudEvent.from_json(json2)
      assert decoded2.data == []
    end
  end

  describe "error handling" do
    test "returns helpful error for missing specversion" do
      json = ~s({"id":"test","source":"/test","type":"com.test","data":{}})

      assert {:error, :invalid_specversion} = CloudEvent.from_json(json)
    end

    test "returns helpful error for missing id" do
      json = ~s({"specversion":"1.0","source":"/test","type":"com.test","data":{}})

      assert {:error, {:missing_field, "id"}} = CloudEvent.from_json(json)
    end

    test "returns helpful error for missing source" do
      json = ~s({"specversion":"1.0","id":"test","type":"com.test","data":{}})

      assert {:error, {:missing_field, "source"}} = CloudEvent.from_json(json)
    end

    test "returns helpful error for missing type" do
      json = ~s({"specversion":"1.0","id":"test","source":"/test","data":{}})

      assert {:error, {:missing_field, "type"}} = CloudEvent.from_json(json)
    end

    test "returns helpful error for missing data" do
      json = ~s({"specversion":"1.0","id":"test","source":"/test","type":"com.test"})

      assert {:error, {:missing_field, "data"}} = CloudEvent.from_json(json)
    end

    test "returns decode error for invalid JSON" do
      json = "{invalid json"

      assert {:error, {:decode_error, _}} = CloudEvent.from_json(json)
    end

    test "returns error for wrong specversion" do
      json = ~s({"specversion":"0.3","id":"test","source":"/test","type":"com.test","data":{}})

      assert {:error, :invalid_specversion} = CloudEvent.from_json(json)
    end

    test "returns error for empty required fields" do
      # Empty id
      json1 = ~s({"specversion":"1.0","id":"","source":"/test","type":"com.test","data":{}})
      assert {:error, {:missing_field, "id"}} = CloudEvent.from_json(json1)

      # Empty source
      json2 = ~s({"specversion":"1.0","id":"test","source":"","type":"com.test","data":{}})
      assert {:error, {:missing_field, "source"}} = CloudEvent.from_json(json2)

      # Empty type
      json3 = ~s({"specversion":"1.0","id":"test","source":"/test","type":"","data":{}})
      assert {:error, {:missing_field, "type"}} = CloudEvent.from_json(json3)
    end
  end

  describe "Unicode and special characters" do
    test "handles UTF-8 strings in data" do
      data = %{
        "message" => "Hello 世界",
        "emoji" => "🎉🚀",
        "special" => "©®™€£¥"
      }

      original = CloudEvent.new!(source: "/test", type: "com.test.event", data: data)
      assert {:ok, json} = CloudEvent.to_json(original)
      assert {:ok, decoded} = CloudEvent.from_json(json)

      assert decoded.data["message"] == "Hello 世界"
      assert decoded.data["emoji"] == "🎉🚀"
      assert decoded.data["special"] == "©®™€£¥"
    end

    test "handles Unicode in source field" do
      event = CloudEvent.new!(source: "/测试/来源", type: "com.test.event", data: %{})
      assert event.source == "/测试/来源"
    end

    test "handles Unicode in type field" do
      event = CloudEvent.new!(source: "/test", type: "com.测试.event", data: %{})
      assert event.type == "com.测试.event"
    end

    test "handles Unicode in subject field" do
      event =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: %{},
          subject: "主题-123"
        )

      assert event.subject == "主题-123"
    end

    test "handles Unicode in extension values" do
      event = CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})
      event = CloudEvent.put_extension(event, "chinese", "中文测试")
      event = CloudEvent.put_extension(event, "emoji", "😀🎉")

      assert event.extensions["chinese"] == "中文测试"
      assert event.extensions["emoji"] == "😀🎉"
    end

    test "round-trips various scripts" do
      scripts = %{
        "arabic" => "مرحبا",
        "cyrillic" => "Привет",
        "greek" => "Γειά",
        "hebrew" => "שלום",
        "japanese" => "こんにちは",
        "korean" => "안녕하세요",
        "thai" => "สวัสดี"
      }

      original = CloudEvent.new!(source: "/test", type: "com.test.event", data: scripts)
      assert {:ok, json} = CloudEvent.to_json(original)
      assert {:ok, decoded} = CloudEvent.from_json(json)

      assert decoded.data["arabic"] == "مرحبا"
      assert decoded.data["cyrillic"] == "Привет"
      assert decoded.data["greek"] == "Γειά"
      assert decoded.data["hebrew"] == "שלום"
      assert decoded.data["japanese"] == "こんにちは"
      assert decoded.data["korean"] == "안녕하세요"
      assert decoded.data["thai"] == "สวัสดี"
    end

    test "handles special JSON characters" do
      data = %{
        "quotes" => "He said \"Hello\"",
        "newlines" => "Line 1\nLine 2\nLine 3",
        "tabs" => "Column1\tColumn2\tColumn3",
        "backslash" => "Path\\to\\file"
      }

      original = CloudEvent.new!(source: "/test", type: "com.test.event", data: data)
      assert {:ok, json} = CloudEvent.to_json(original)
      assert {:ok, decoded} = CloudEvent.from_json(json)

      assert decoded.data["quotes"] == "He said \"Hello\""
      assert decoded.data["newlines"] == "Line 1\nLine 2\nLine 3"
      assert decoded.data["tabs"] == "Column1\tColumn2\tColumn3"
      assert decoded.data["backslash"] == "Path\\to\\file"
    end
  end

  describe "timestamp handling" do
    test "preserves DateTime precision through round-trip" do
      dt = DateTime.from_iso8601("2024-06-15T14:30:45.123456Z") |> elem(1)

      original = CloudEvent.new!(source: "/test", type: "com.test.event", data: %{}, time: dt)
      assert {:ok, json} = CloudEvent.to_json(original)
      assert {:ok, decoded} = CloudEvent.from_json(json)

      assert decoded.time.microsecond == dt.microsecond
    end

    test "parses various ISO 8601 formats" do
      formats = [
        "2024-01-15T12:30:45Z",
        "2024-01-15T12:30:45.123Z",
        "2024-01-15T12:30:45.123456Z",
        "2024-01-15T12:30:45+00:00",
        "2024-01-15T12:30:45.123+00:00"
      ]

      Enum.each(formats, fn format ->
        json = ~s({
          "specversion": "1.0",
          "id": "test",
          "source": "/test",
          "type": "com.test",
          "data": {},
          "time": "#{format}"
        })

        assert {:ok, event} = CloudEvent.from_json(json)
        assert %DateTime{} = event.time
      end)
    end

    test "encodes DateTime with microseconds" do
      dt = DateTime.from_iso8601("2024-06-15T14:30:45.123456Z") |> elem(1)
      event = CloudEvent.new!(source: "/test", type: "com.test.event", data: %{}, time: dt)

      assert {:ok, json} = CloudEvent.to_json(event)
      assert {:ok, _decoded} = CloudEvent.from_json(json)

      # Microsecond precision should be preserved
      assert String.contains?(json, "123456")
    end

    test "keeps invalid time as string" do
      json = ~s({
        "specversion": "1.0",
        "id": "test",
        "source": "/test",
        "type": "com.test",
        "data": {},
        "time": "not-a-valid-timestamp"
      })

      assert {:ok, event} = CloudEvent.from_json(json)
      assert event.time == "not-a-valid-timestamp"
    end

    test "handles leap year and edge dates" do
      # Leap year
      dt1 = DateTime.from_iso8601("2024-02-29T12:00:00Z") |> elem(1)
      event1 = CloudEvent.new!(source: "/test", type: "com.test.event", data: %{}, time: dt1)
      assert {:ok, _} = CloudEvent.to_json(event1)

      # End of year
      dt2 = DateTime.from_iso8601("2024-12-31T23:59:59.999999Z") |> elem(1)
      event2 = CloudEvent.new!(source: "/test", type: "com.test.event", data: %{}, time: dt2)
      assert {:ok, _} = CloudEvent.to_json(event2)

      # Start of year
      dt3 = DateTime.from_iso8601("2024-01-01T00:00:00.000000Z") |> elem(1)
      event3 = CloudEvent.new!(source: "/test", type: "com.test.event", data: %{}, time: dt3)
      assert {:ok, _} = CloudEvent.to_json(event3)
    end
  end

  describe "extension attributes" do
    test "handles string extension values" do
      json = ~s({
        "specversion": "1.0",
        "id": "test",
        "source": "/test",
        "type": "com.test",
        "data": {},
        "customstring": "value"
      })

      assert {:ok, event} = CloudEvent.from_json(json)
      assert event.extensions["customstring"] == "value"
    end

    test "handles numeric extension values" do
      json = ~s({
        "specversion": "1.0",
        "id": "test",
        "source": "/test",
        "type": "com.test",
        "data": {},
        "customint": 42,
        "customfloat": 3.14
      })

      assert {:ok, event} = CloudEvent.from_json(json)
      assert event.extensions["customint"] == 42
      assert event.extensions["customfloat"] == 3.14
    end

    test "handles boolean extension values" do
      json = ~s({
        "specversion": "1.0",
        "id": "test",
        "source": "/test",
        "type": "com.test",
        "data": {},
        "customtrue": true,
        "customfalse": false
      })

      assert {:ok, event} = CloudEvent.from_json(json)
      assert event.extensions["customtrue"] == true
      assert event.extensions["customfalse"] == false
    end

    test "handles null extension values" do
      json = ~s({
        "specversion": "1.0",
        "id": "test",
        "source": "/test",
        "type": "com.test",
        "data": {},
        "customnull": null
      })

      assert {:ok, event} = CloudEvent.from_json(json)
      assert event.extensions["customnull"] == nil
    end

    test "preserves multiple extensions through round-trip" do
      original = CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})
      original = CloudEvent.put_extension(original, "ext1", "value1")
      original = CloudEvent.put_extension(original, "ext2", 42)
      original = CloudEvent.put_extension(original, "ext3", true)
      original = CloudEvent.put_extension(original, "ext4", nil)

      assert {:ok, json} = CloudEvent.to_json(original)
      assert {:ok, decoded} = CloudEvent.from_json(json)

      assert decoded.extensions["ext1"] == "value1"
      assert decoded.extensions["ext2"] == 42
      assert decoded.extensions["ext3"] == true
      assert decoded.extensions["ext4"] == nil
    end

    test "extracts non-spec attributes as extensions" do
      # All non-spec attributes should go to extensions
      json = ~s({
        "specversion": "1.0",
        "id": "test",
        "source": "/test",
        "type": "com.test",
        "data": {},
        "correlationid": "abc-123",
        "userid": "user-456",
        "traceid": "trace-789"
      })

      assert {:ok, event} = CloudEvent.from_json(json)
      assert map_size(event.extensions) == 3
      assert event.extensions["correlationid"] == "abc-123"
      assert event.extensions["userid"] == "user-456"
      assert event.extensions["traceid"] == "trace-789"
    end
  end

  describe "base64 encoding/decoding" do
    test "encodes and decodes binary data" do
      original =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: "binary data: 🎉",
          datacontentencoding: "base64"
        )

      assert {:ok, json} = CloudEvent.to_json(original)
      # Should have data_base64 instead of data
      assert String.contains?(json, "data_base64")

      assert {:ok, decoded} = CloudEvent.from_json(json)
      assert decoded.data == "binary data: 🎉"
    end

    test "encodes and decodes JSON as base64" do
      data = %{"message" => "Hello", "value" => 42}

      original =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: data,
          datacontentencoding: "base64"
        )

      assert {:ok, json} = CloudEvent.to_json(original)
      assert {:ok, decoded} = CloudEvent.from_json(json)

      # Data should be decoded from base64 and parsed as JSON
      assert decoded.data["message"] == "Hello"
      assert decoded.data["value"] == 42
    end

    test "handles empty binary data" do
      original =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: "",
          datacontentencoding: "base64"
        )

      assert {:ok, json} = CloudEvent.to_json(original)
      assert {:ok, decoded} = CloudEvent.from_json(json)

      assert decoded.data == ""
    end

    test "round-trips binary with Unicode" do
      data = "Hello 世界 🎉 Привет مرحبا"

      original =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: data,
          datacontentencoding: "base64"
        )

      assert {:ok, json} = CloudEvent.to_json(original)
      assert {:ok, decoded} = CloudEvent.from_json(json)

      assert decoded.data == data
    end

    test "handles large binary payloads" do
      # Create a large binary payload (100KB)
      large_data = :crypto.strong_rand_bytes(100_000)

      original =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: large_data,
          datacontentencoding: "base64"
        )

      assert {:ok, json} = CloudEvent.to_json(original)
      assert {:ok, decoded} = CloudEvent.from_json(json)

      assert decoded.data == large_data
    end
  end

  describe "interoperability" do
    test "can encode and decode with external CloudEvents implementations" do
      # Simulate receiving an event from another implementation
      external_json = ~s({
        "specversion": "1.0",
        "id": "external-event-123",
        "source": "https://external-service.com/events",
        "type": "com.external.event",
        "datacontenttype": "application/json",
        "subject": "entity-456",
        "time": "2024-01-15T10:20:30Z",
        "data": {
          "externalField": "externalValue",
          "timestamp": 1705315230
        },
        "correlationId": "ext-correlation-abc"
      })

      assert {:ok, event} = CloudEvent.from_json(external_json)

      # Verify all fields are correctly parsed
      assert event.specversion == "1.0"
      assert event.id == "external-event-123"
      assert event.source == "https://external-service.com/events"
      assert event.type == "com.external.event"
      assert event.datacontenttype == "application/json"
      assert event.subject == "entity-456"
      assert event.data["externalField"] == "externalValue"
      assert event.data["timestamp"] == 1_705_315_230
      assert event.extensions["correlationId"] == "ext-correlation-abc"

      # Verify we can serialize it back
      assert {:ok, new_json} = CloudEvent.to_json(event)
      assert {:ok, round_trip} = CloudEvent.from_json(new_json)

      assert round_trip.id == event.id
      assert round_trip.data["externalField"] == "externalValue"
    end
  end
end
