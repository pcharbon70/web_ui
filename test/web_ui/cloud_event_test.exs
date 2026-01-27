defmodule WebUi.CloudEventTest do
  use ExUnit.Case, async: true

  @moduletag :cloudevent

  doctest WebUi.CloudEvent

  alias WebUi.CloudEvent

  describe "struct creation" do
    test "creates struct with all required fields" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "test-id-123",
        source: "/test/source",
        type: "com.test.event",
        data: %{message: "Hello"}
      }

      assert event.specversion == "1.0"
      assert event.id == "test-id-123"
      assert event.source == "/test/source"
      assert event.type == "com.test.event"
      assert event.data == %{message: "Hello"}
    end

    test "creates struct with optional fields" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "test-id-123",
        source: "/test/source",
        type: "com.test.event",
        data: %{message: "Hello"},
        datacontenttype: "application/json",
        subject: "test-subject",
        time: "2024-01-01T00:00:00Z",
        extensions: %{"custom-attr" => "custom-value"}
      }

      assert event.datacontenttype == "application/json"
      assert event.subject == "test-subject"
      assert event.time == "2024-01-01T00:00:00Z"
      assert event.extensions == %{"custom-attr" => "custom-value"}
    end

    test "struct defaults to nil for optional fields" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "test-id-123",
        source: "/test/source",
        type: "com.test.event",
        data: %{}
      }

      assert is_nil(event.datacontenttype)
      assert is_nil(event.datacontentencoding)
      assert is_nil(event.subject)
      assert is_nil(event.time)
      assert is_nil(event.extensions)
    end
  end

  describe "new!/1" do
    test "creates event with required fields" do
      event =
        CloudEvent.new!(
          source: "/test/source",
          type: "com.test.event",
          data: %{message: "Hello"}
        )

      assert event.specversion == "1.0"
      assert event.source == "/test/source"
      assert event.type == "com.test.event"
      assert event.data == %{message: "Hello"}
      assert is_binary(event.id)
      # UUID v4 format
      assert byte_size(event.id) == 36
    end

    test "creates event with custom id" do
      event =
        CloudEvent.new!(
          id: "custom-id",
          source: "/test/source",
          type: "com.test.event",
          data: %{}
        )

      assert event.id == "custom-id"
    end

    test "creates event with optional fields" do
      time = DateTime.utc_now()

      event =
        CloudEvent.new!(
          source: "/test/source",
          type: "com.test.event",
          data: %{message: "Hello"},
          datacontenttype: "application/json",
          subject: "test-subject",
          time: time,
          extensions: %{"custom" => "value"}
        )

      assert event.datacontenttype == "application/json"
      assert event.subject == "test-subject"
      assert event.time == time
      assert event.extensions == %{"custom" => "value"}
    end

    test "raises ArgumentError when source is nil" do
      assert_raise ArgumentError, fn ->
        CloudEvent.new!(source: nil, type: "com.test.event", data: %{})
      end
    end

    test "raises ArgumentError when source is empty string" do
      assert_raise ArgumentError, fn ->
        CloudEvent.new!(source: "", type: "com.test.event", data: %{})
      end
    end

    test "raises ArgumentError when type is nil" do
      assert_raise ArgumentError, fn ->
        CloudEvent.new!(source: "/test", type: nil, data: %{})
      end
    end

    test "raises ArgumentError when type is empty string" do
      assert_raise ArgumentError, fn ->
        CloudEvent.new!(source: "/test", type: "", data: %{})
      end
    end

    test "accepts nil as data" do
      event =
        CloudEvent.new!(
          source: "/test/source",
          type: "com.test.event",
          data: nil
        )

      assert event.data == nil
    end
  end

  describe "new/1" do
    test "returns {:ok, event} on success" do
      assert {:ok, event} =
               CloudEvent.new(
                 source: "/test/source",
                 type: "com.test.event",
                 data: %{message: "Hello"}
               )

      assert %CloudEvent{} = event
    end

    test "returns {:error, reason} on validation failure" do
      assert {:error, :validation_failed} =
               CloudEvent.new(
                 source: nil,
                 type: "com.test.event",
                 data: %{}
               )
    end
  end

  describe "validate/1" do
    test "returns :ok for valid event" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "test-id",
        source: "/test/source",
        type: "com.test.event",
        data: %{}
      }

      assert :ok = CloudEvent.validate(event)
    end

    test "returns {:error, :invalid_specversion} for wrong version" do
      event = %CloudEvent{
        specversion: "0.3",
        id: "test-id",
        source: "/test/source",
        type: "com.test.event",
        data: %{}
      }

      assert {:error, :invalid_specversion} = CloudEvent.validate(event)
    end

    test "returns {:error, :invalid_id} for empty id" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "",
        source: "/test/source",
        type: "com.test.event",
        data: %{}
      }

      assert {:error, :invalid_id} = CloudEvent.validate(event)
    end

    test "returns {:error, :invalid_source} for empty source" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "test-id",
        source: "",
        type: "com.test.event",
        data: %{}
      }

      assert {:error, :invalid_source} = CloudEvent.validate(event)
    end

    test "returns {:error, :invalid_type} for empty type" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "test-id",
        source: "/test/source",
        type: "",
        data: %{}
      }

      assert {:error, :invalid_type} = CloudEvent.validate(event)
    end

    test "returns {:error, :not_a_cloudevent} for non-struct" do
      assert {:error, :not_a_cloudevent} = CloudEvent.validate(%{})
      assert {:error, :not_a_cloudevent} = CloudEvent.validate("not an event")
      assert {:error, :not_a_cloudevent} = CloudEvent.validate(nil)
    end

    test "accepts nil datacontenttype" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "test-id",
        source: "/test/source",
        type: "com.test.event",
        data: %{},
        datacontenttype: nil
      }

      assert :ok = CloudEvent.validate(event)
    end

    test "accepts valid datacontenttype" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "test-id",
        source: "/test/source",
        type: "com.test.event",
        data: %{},
        datacontenttype: "application/json"
      }

      assert :ok = CloudEvent.validate(event)
    end
  end

  describe "generate_id/0" do
    test "generates a valid UUID v4" do
      id = CloudEvent.generate_id()

      assert is_binary(id)
      assert byte_size(id) == 36

      # UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      assert Regex.match?(
               ~r/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
               id
             )
    end

    test "generates unique IDs" do
      ids = Enum.map(1..100, fn _ -> CloudEvent.generate_id() end)
      assert Enum.uniq(ids) |> length() == 100
    end
  end

  describe "source/2" do
    test "creates URN source from components" do
      assert CloudEvent.source("my-app", "user-service") == "urn:my-app:user-service"
    end

    test "creates HTTPS source from components" do
      assert CloudEvent.source("https://example.com", "/api/events") ==
               "https://example.com/api/events"
    end

    test "creates HTTP source from components" do
      assert CloudEvent.source("http://example.com", "/api/events") ==
               "http://example.com/api/events"
    end

    test "handles existing URN prefix" do
      assert CloudEvent.source("urn:my-app", "service") == "urn:my-app:service"
    end

    test "trims leading colons from path" do
      assert CloudEvent.source("my-app", ":service") == "urn:my-app:service"
      assert CloudEvent.source("my-app", "service") == "urn:my-app:service"
    end
  end

  describe "cloudevent?/1" do
    test "returns true for CloudEvent struct" do
      event = %CloudEvent{
        specversion: "1.0",
        id: "test-id",
        source: "/test/source",
        type: "com.test.event",
        data: %{}
      }

      assert CloudEvent.cloudevent?(event)
    end

    test "returns false for non-CloudEvent values" do
      refute CloudEvent.cloudevent?(%{})
      refute CloudEvent.cloudevent?(%{specversion: "1.0"})
      refute CloudEvent.cloudevent?(nil)
      refute CloudEvent.cloudevent?("string")
      refute CloudEvent.cloudevent?(123)
    end
  end

  describe "data field types" do
    test "accepts map as data" do
      event =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: %{key: "value", nested: %{a: 1}}
        )

      assert event.data == %{key: "value", nested: %{a: 1}}
    end

    test "accepts list as data" do
      event =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: [1, 2, 3]
        )

      assert event.data == [1, 2, 3]
    end

    test "accepts string as data" do
      event =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: "plain text data"
        )

      assert event.data == "plain text data"
    end

    test "accepts number as data" do
      event =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: 42
        )

      assert event.data == 42
    end

    test "accepts boolean as data" do
      event =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: true
        )

      assert event.data == true
    end

    test "accepts nil as data" do
      event =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: nil
        )

      assert is_nil(event.data)
    end
  end

  describe "extensions" do
    test "accepts extensions map" do
      event =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: %{},
          extensions: %{"custom-attr" => "value", "another-attr" => 123}
        )

      assert event.extensions["custom-attr"] == "value"
      assert event.extensions["another-attr"] == 123
    end

    test "accepts nil extensions" do
      event =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: %{},
          extensions: nil
        )

      assert is_nil(event.extensions)
    end
  end

  describe "specversion/0" do
    test "returns the supported specversion" do
      assert CloudEvent.specversion() == "1.0"
    end
  end

  describe "type specification" do
    @tag :dialyzer
    test "dialyzer can analyze CloudEvent types" do
      # This test exists to document that Dialyzer should successfully
      # analyze the @type specifications in the CloudEvent module
      event = %CloudEvent{
        specversion: "1.0",
        id: "test",
        source: "/test",
        type: "com.test",
        data: %{}
      }

      assert is_struct(event)
    end
  end
end
