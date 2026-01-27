defmodule WebUi.CloudEventJSONTest do
  use ExUnit.Case, async: true

  @moduletag :cloudevent_json

  alias WebUi.CloudEvent

  describe "to_json/1 and to_json!/1" do
    test "encodes valid CloudEvent to JSON" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "test-id-123",
        source: "/test/source",
        type: "com.test.event",
        data: %{message: "Hello World"}
      }

      assert {:ok, json} = CloudEvent.to_json(event)
      assert is_binary(json)

      # Verify it's valid JSON
      assert {:ok, decoded} = Jason.decode(json)
      assert decoded["specversion"] == "1.0"
      assert decoded["id"] == "test-id-123"
      assert decoded["source"] == "/test/source"
      assert decoded["type"] == "com.test.event"
      assert decoded["data"]["message"] == "Hello World"
    end

    test "encodes event with optional fields" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "test-id",
        source: "/test",
        type: "com.test.event",
        data: %{value: 42},
        datacontenttype: "application/json",
        subject: "test-subject",
        time: "2024-01-01T00:00:00Z"
      }

      assert {:ok, json} = CloudEvent.to_json(event)
      assert {:ok, decoded} = Jason.decode(json)

      assert decoded["datacontenttype"] == "application/json"
      assert decoded["subject"] == "test-subject"
      assert decoded["time"] == "2024-01-01T00:00:00Z"
    end

    test "encodes event with DateTime" do
      dt = DateTime.from_iso8601("2024-01-15T12:30:45Z") |> elem(1)

      event = %CloudEvent{
        specversion: "1.0",
        id: "test-id",
        source: "/test",
        type: "com.test.event",
        data: %{},
        time: dt
      }

      assert {:ok, json} = CloudEvent.to_json(event)
      assert {:ok, decoded} = Jason.decode(json)
      assert decoded["time"] == "2024-01-15T12:30:45Z"
    end

    test "to_json!/1 raises on error for invalid input" do
      assert_raise ArgumentError, ~r/not a CloudEvent/, fn ->
        CloudEvent.to_json!(%{})
      end
    end

    test "encodes nil data correctly" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "test-id",
        source: "/test",
        type: "com.test.event",
        data: nil
      }

      assert {:ok, json} = CloudEvent.to_json(event)
      assert {:ok, decoded} = Jason.decode(json)
      assert decoded["data"] == nil
    end

    test "encodes extensions correctly" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "test-id",
        source: "/test",
        type: "com.test.event",
        data: %{},
        extensions: %{"custom-attr" => "custom-value", "number-attr" => 42}
      }

      assert {:ok, json} = CloudEvent.to_json(event)
      assert {:ok, decoded} = Jason.decode(json)
      assert decoded["custom-attr"] == "custom-value"
      assert decoded["number-attr"] == 42
    end
  end

  describe "from_json/1 and from_json!/1" do
    test "decodes valid JSON to CloudEvent" do
      json = ~s({
        "specversion": "1.0",
        "id": "test-id",
        "source": "/test/source",
        "type": "com.test.event",
        "data": {"message": "Hello"}
      })

      assert {:ok, event} = CloudEvent.from_json(json)
      assert event.specversion == "1.0"
      assert event.id == "test-id"
      assert event.source == "/test/source"
      assert event.type == "com.test.event"
      assert event.data["message"] == "Hello"
    end

    test "decodes JSON with optional fields" do
      json = ~s({
        "specversion": "1.0",
        "id": "test-id",
        "source": "/test",
        "type": "com.test.event",
        "data": {},
        "datacontenttype": "application/json",
        "subject": "test-subject",
        "time": "2024-01-01T00:00:00Z"
      })

      assert {:ok, event} = CloudEvent.from_json(json)
      assert event.datacontenttype == "application/json"
      assert event.subject == "test-subject"
      # time is parsed to DateTime
      assert %DateTime{} = event.time
    end

    test "decodes JSON with extensions" do
      json = ~s({
        "specversion": "1.0",
        "id": "test-id",
        "source": "/test",
        "type": "com.test.event",
        "data": {},
        "customattr": "value",
        "anotherattr": 123
      })

      assert {:ok, event} = CloudEvent.from_json(json)
      assert event.extensions["customattr"] == "value"
      assert event.extensions["anotherattr"] == 123
    end

    test "returns error on missing required field" do
      # Missing id
      json = ~s({
        "specversion": "1.0",
        "source": "/test",
        "type": "com.test.event",
        "data": {}
      })

      assert {:error, {:missing_field, "id"}} = CloudEvent.from_json(json)
    end

    test "returns error on invalid JSON" do
      json = "not valid json"

      assert {:error, {:decode_error, _}} = CloudEvent.from_json(json)
    end

    test "from_json!/1 raises on error" do
      json = "not valid json"

      assert_raise ArgumentError, ~r/from_json! failed/, fn ->
        CloudEvent.from_json!(json)
      end
    end
  end

  describe "to_json_map/1" do
    test "converts CloudEvent to map" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "test-id",
        source: "/test/source",
        type: "com.test.event",
        data: %{"message" => "Hello"}
      }

      map = CloudEvent.to_json_map(event)

      assert map["specversion"] == "1.0"
      assert map["id"] == "test-id"
      assert map["source"] == "/test/source"
      assert map["type"] == "com.test.event"
      # Data is set via put_data, not put_optional
      assert map["data"]["message"] == "Hello"
    end

    test "includes optional fields when present" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "test-id",
        source: "/test",
        type: "com.test.event",
        data: %{},
        subject: "test-subject"
      }

      map = CloudEvent.to_json_map(event)

      assert map["subject"] == "test-subject"
    end

    test "omits nil optional fields" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "test-id",
        source: "/test",
        type: "com.test.event",
        data: %{},
        datacontenttype: nil,
        subject: nil,
        time: nil
      }

      map = CloudEvent.to_json_map(event)

      refute Map.has_key?(map, "datacontenttype")
      refute Map.has_key?(map, "subject")
      refute Map.has_key?(map, "time")
    end
  end

  describe "from_json_map/1" do
    test "decodes map to CloudEvent" do
      map = %{
        "specversion" => "1.0",
        "id" => "test-id",
        "source" => "/test/source",
        "type" => "com.test.event",
        "data" => %{"message" => "Hello"}
      }

      assert {:ok, event} = CloudEvent.from_json_map(map)
      assert event.specversion == "1.0"
      assert event.id == "test-id"
      assert event.source == "/test/source"
      assert event.type == "com.test.event"
      assert event.data["message"] == "Hello"
    end

    test "extracts extensions from map" do
      map = %{
        "specversion" => "1.0",
        "id" => "test-id",
        "source" => "/test",
        "type" => "com.test.event",
        "data" => %{},
        "customattr" => "value",
        "anotherattr" => 42
      }

      assert {:ok, event} = CloudEvent.from_json_map(map)
      assert event.extensions["customattr"] == "value"
      assert event.extensions["anotherattr"] == 42
    end

    test "returns error on missing specversion" do
      map = %{
        "id" => "test-id",
        "source" => "/test",
        "type" => "com.test.event",
        "data" => %{}
      }

      assert {:error, :invalid_specversion} = CloudEvent.from_json_map(map)
    end

    test "returns error on invalid specversion" do
      map = %{
        "specversion" => "0.3",
        "id" => "test-id",
        "source" => "/test",
        "type" => "com.test.event",
        "data" => %{}
      }

      assert {:error, :invalid_specversion} = CloudEvent.from_json_map(map)
    end

    test "returns error on missing required field" do
      map = %{
        "specversion" => "1.0",
        "id" => "test-id",
        "source" => "/test",
        "type" => "com.test.event"
        # Missing "data"
      }

      # data field is required but can be nil - if missing, should error
      # Actually, in CloudEvents spec, data IS required even if null
      assert {:error, {:missing_field, "data"}} = CloudEvent.from_json_map(map)
    end

    test "accepts nil data when data field is present" do
      map = %{
        "specversion" => "1.0",
        "id" => "test-id",
        "source" => "/test",
        "type" => "com.test.event",
        "data" => nil
      }

      assert {:ok, event} = CloudEvent.from_json_map(map)
      assert is_nil(event.data)
    end
  end

  describe "round-trip encoding/decoding" do
    test "round-trip preserves all fields" do
      original =
        CloudEvent.new!(
          source: "/test/source",
          type: "com.test.event",
          data: %{message: "Hello", number: 42},
          datacontenttype: "application/json",
          subject: "test-subject",
          extensions: %{"custom" => "value"}
        )

      assert {:ok, json} = CloudEvent.to_json(original)
      assert {:ok, decoded} = CloudEvent.from_json(json)

      assert decoded.specversion == original.specversion
      assert decoded.id == original.id
      assert decoded.source == original.source
      assert decoded.type == original.type
      # Data keys are converted to strings by JSON decode
      assert decoded.data["message"] == "Hello"
      assert decoded.data["number"] == 42
      assert decoded.datacontenttype == original.datacontenttype
      assert decoded.subject == original.subject
      assert decoded.extensions == original.extensions
    end

    test "round-trip with DateTime" do
      dt = DateTime.utc_now()

      original =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: %{},
          time: dt
        )

      assert {:ok, json} = CloudEvent.to_json(original)
      assert {:ok, decoded} = CloudEvent.from_json(json)

      # DateTime is preserved (compared by equality, not exact instance)
      assert DateTime.compare(decoded.time, dt) == :eq
    end

    test "round-trip with nil data" do
      original =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: nil
        )

      assert {:ok, json} = CloudEvent.to_json(original)
      assert {:ok, decoded} = CloudEvent.from_json(json)

      assert is_nil(decoded.data)
    end

    test "round-trip preserves various data types" do
      data_types = [
        %{map: "data"},
        [1, 2, 3],
        "string data",
        42,
        true,
        false,
        nil
      ]

      Enum.each(data_types, fn data ->
        original =
          CloudEvent.new!(
            source: "/test",
            type: "com.test.event",
            data: data
          )

        assert {:ok, json} = CloudEvent.to_json(original)
        assert {:ok, decoded} = CloudEvent.from_json(json)

        # After JSON decode, atom keys become string keys
        expected =
          case data do
            %{map: "data"} -> %{"map" => "data"}
            _ -> data
          end

        assert decoded.data == expected
      end)
    end
  end

  describe "timestamp handling" do
    test "encodes DateTime as ISO 8601 string" do
      dt = DateTime.from_iso8601("2024-06-15T14:30:45Z") |> elem(1)

      map =
        CloudEvent.to_json_map(%CloudEvent{
          specversion: "1.0",
          id: "test-id",
          source: "/test",
          type: "com.test.event",
          data: %{},
          time: dt
        })

      assert map["time"] == "2024-06-15T14:30:45Z"
    end

    test "decodes ISO 8601 string to DateTime" do
      json = ~s({
        "specversion": "1.0",
        "id": "test-id",
        "source": "/test",
        "type": "com.test.event",
        "data": {},
        "time": "2024-06-15T14:30:45Z"
      })

      assert {:ok, event} = CloudEvent.from_json(json)
      assert %DateTime{} = event.time
      assert event.time.year == 2024
      assert event.time.month == 6
      assert event.time.day == 15
    end

    test "keeps time as string if not valid ISO 8601" do
      json = ~s({
        "specversion": "1.0",
        "id": "test-id",
        "source": "/test",
        "type": "com.test.event",
        "data": {},
        "time": "not-a-valid-timestamp"
      })

      assert {:ok, event} = CloudEvent.from_json(json)
      assert event.time == "not-a-valid-timestamp"
    end

    test "handles nil time" do
      json = ~s({
        "specversion": "1.0",
        "id": "test-id",
        "source": "/test",
        "type": "com.test.event",
        "data": {}
      })

      assert {:ok, event} = CloudEvent.from_json(json)
      assert is_nil(event.time)
    end
  end

  describe "base64 encoding/decoding" do
    test "encodes binary data with base64 encoding" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "test-id",
        source: "/test",
        type: "com.test.event",
        data: "binary data",
        datacontentencoding: "base64"
      }

      assert {:ok, json} = CloudEvent.to_json(event)
      assert {:ok, decoded} = Jason.decode(json)

      # Should have data_base64 instead of data
      assert Map.has_key?(decoded, "data_base64")
      refute Map.has_key?(decoded, "data")
    end

    test "decodes base64 encoded data" do
      # "hello" in base64 is "aGVsbG8="
      json = ~s({
        "specversion": "1.0",
        "id": "test-id",
        "source": "/test",
        "type": "com.test.event",
        "data_base64": "aGVsbG8=",
        "datacontentencoding": "base64"
      })

      assert {:ok, event} = CloudEvent.from_json(json)
      # Decodes to "hello"
      assert event.data == "hello"
    end

    test "round-trip with base64 encoding" do
      original =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: "binary data to encode",
          datacontentencoding: "base64"
        )

      assert {:ok, json} = CloudEvent.to_json(original)
      assert {:ok, decoded} = CloudEvent.from_json(json)

      assert decoded.datacontentencoding == "base64"
      assert decoded.data == "binary data to encode"
    end
  end

  describe "error messages" do
    test "from_json returns helpful error for missing id" do
      json = ~s({
        "specversion": "1.0",
        "source": "/test",
        "type": "com.test.event",
        "data": {}
      })

      assert {:error, {:missing_field, "id"}} = CloudEvent.from_json(json)
    end

    test "from_json returns helpful error for missing source" do
      json = ~s({
        "specversion": "1.0",
        "id": "test-id",
        "type": "com.test.event",
        "data": {}
      })

      assert {:error, {:missing_field, "source"}} = CloudEvent.from_json(json)
    end

    test "from_json returns helpful error for missing type" do
      json = ~s({
        "specversion": "1.0",
        "id": "test-id",
        "source": "/test",
        "data": {}
      })

      assert {:error, {:missing_field, "type"}} = CloudEvent.from_json(json)
    end

    test "from_json returns helpful error for missing data" do
      json = ~s({"specversion":"1.0","id":"test-id","source":"/test","type":"com.test.event"})

      assert {:error, {:missing_field, "data"}} = CloudEvent.from_json(json)
    end
  end

  describe "JSON interop with standard CloudEvents" do
    test "decodes standard CloudEvents JSON example" do
      # Example from CloudEvents spec
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
      assert event.type == "com.github.pull_request.opened"
      assert event.source == "https://github.com/cloudevents/spec/pull"
      assert event.id == "A234-1234-1234"
      assert event.datacontenttype == "application/json"
      assert event.data["pullrequest"]["id"] == 123
    end

    test "encodes to standard CloudEvents JSON format" do
      event =
        CloudEvent.new!(
          source: "https://example.com",
          type: "com.example.order.created",
          data: %{order_id: "ABC123", total: 99.99}
        )

      assert {:ok, json} = CloudEvent.to_json(event)
      assert {:ok, decoded} = Jason.decode(json)

      # Verify standard CloudEvents structure
      assert decoded["specversion"] == "1.0"
      assert Map.has_key?(decoded, "id")
      assert Map.has_key?(decoded, "source")
      assert Map.has_key?(decoded, "type")
      assert Map.has_key?(decoded, "data")
    end
  end
end
