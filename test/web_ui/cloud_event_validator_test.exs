defmodule WebUi.CloudEvent.ValidatorTest do
  use ExUnit.Case, async: true
  doctest WebUi.CloudEvent.Validator

  alias WebUi.CloudEvent
  alias WebUi.CloudEvent.Validator

  describe "validate_full/1" do
    test "validates a valid CloudEvent" do
      event =
        CloudEvent.new!(
          source: "/test",
          type: "com.example.event",
          data: %{}
        )

      assert Validator.validate_full(event) == :ok
    end

    test "validates event with all optional fields" do
      dt = DateTime.from_iso8601("2024-01-15T12:30:45Z") |> elem(1)

      event =
        CloudEvent.new!(
          source: "/test",
          type: "com.example.event",
          data: %{message: "Hello"},
          datacontenttype: "application/json",
          subject: "test-subject",
          time: dt,
          extensions: %{"traceid" => "abc123"}
        )

      assert Validator.validate_full(event) == :ok
    end

    test "returns error for non-CloudEvent input" do
      assert Validator.validate_full(%{}) == {:error, :not_a_cloudevent}
      assert Validator.validate_full("not a struct") == {:error, :not_a_cloudevent}
      assert Validator.validate_full(nil) == {:error, :not_a_cloudevent}
    end
  end

  describe "validate_specversion/1" do
    test "accepts version 1.0" do
      assert Validator.validate_specversion("1.0") == :ok
    end

    test "rejects other versions" do
      assert Validator.validate_specversion("2.0") == {:error, :invalid_specversion}
      assert Validator.validate_specversion("0.3") == {:error, :invalid_specversion}
      assert Validator.validate_specversion("") == {:error, :invalid_specversion}
      assert Validator.validate_specversion(nil) == {:error, :invalid_specversion}
    end
  end

  describe "validate_id/1" do
    test "accepts valid IDs" do
      assert Validator.validate_id("A234-1234-1234") == :ok
      assert Validator.validate_id("123") == :ok
      assert Validator.validate_id(Uniq.UUID.uuid4()) == :ok
    end

    test "rejects invalid IDs" do
      assert Validator.validate_id("") == {:error, :invalid_id}
      assert Validator.validate_id(nil) == {:error, :invalid_id}
      assert Validator.validate_id(123) == {:error, :invalid_id}
    end
  end

  describe "validate_source/1" do
    test "accepts valid URI references" do
      assert Validator.validate_source("/my-context") == :ok
      assert Validator.validate_source("https://example.com/events") == :ok
      assert Validator.validate_source("http://localhost:4000") == :ok
      assert Validator.validate_source("urn:example:my-context") == :ok
      assert Validator.validate_source("mailto:test@example.com") == :ok
    end

    test "rejects invalid sources" do
      assert Validator.validate_source("") == {:error, :invalid_source}
      assert Validator.validate_source(nil) == {:error, :invalid_source}
      assert Validator.validate_source(123) == {:error, :invalid_source}
    end
  end

  describe "validate_type/1" do
    test "accepts valid types" do
      assert Validator.validate_type("com.example.event") == :ok
      assert Validator.validate_type("myapp.event") == :ok
      assert Validator.validate_type("com.github.pull_request") == :ok
    end

    test "rejects invalid types" do
      assert Validator.validate_type("") == {:error, :invalid_type}
      assert Validator.validate_type(nil) == {:error, :invalid_type}
      assert Validator.validate_type(123) == {:error, :invalid_type}
    end
  end

  describe "validate_datacontenttype/1" do
    test "accepts nil and valid MIME types" do
      assert Validator.validate_datacontenttype(nil) == :ok
      assert Validator.validate_datacontenttype("application/json") == :ok
      assert Validator.validate_datacontenttype("text/plain") == :ok
      assert Validator.validate_datacontenttype("application/xml") == :ok
    end

    test "rejects non-string, non-nil values" do
      assert Validator.validate_datacontenttype(123) == {:error, :invalid_datacontenttype}
      assert Validator.validate_datacontenttype([]) == {:error, :invalid_datacontenttype}
    end
  end

  describe "validate_time/1" do
    test "accepts nil, DateTime, and valid ISO 8601 strings" do
      assert Validator.validate_time(nil) == :ok

      dt = DateTime.utc_now()
      assert Validator.validate_time(dt) == :ok

      assert Validator.validate_time("2024-01-15T12:30:45Z") == :ok
      assert Validator.validate_time("2024-01-15T12:30:45.123Z") == :ok
    end

    test "rejects invalid time values" do
      assert Validator.validate_time("invalid") == {:error, :invalid_time}
      assert Validator.validate_time("2024-13-01T12:00:00Z") == {:error, :invalid_time}
      assert Validator.validate_time(123) == {:error, :invalid_time}
    end
  end

  describe "validate_extensions/1" do
    test "accepts nil and valid extension maps" do
      assert Validator.validate_extensions(nil) == :ok
      assert Validator.validate_extensions(%{}) == :ok
      assert Validator.validate_extensions(%{"traceid" => "123"}) == :ok
      assert Validator.validate_extensions(%{"custom_attr" => 123}) == :ok
      assert Validator.validate_extensions(%{"flag" => true}) == :ok
      assert Validator.validate_extensions(%{"nullable" => nil}) == :ok
    end

    test "accepts multiple extensions" do
      extensions = %{
        "traceid" => "abc-123",
        "parentid" => "xyz-789",
        "retry_count" => 3
      }

      assert Validator.validate_extensions(extensions) == :ok
    end

    test "rejects invalid extension names" do
      assert Validator.validate_extensions(%{"InvalidName" => "x"}) ==
               {:error, :invalid_extension}

      assert Validator.validate_extensions(%{"UPPERCASE" => "x"}) ==
               {:error, :invalid_extension}

      assert Validator.validate_extensions(%{"123number" => "x"}) ==
               {:error, :invalid_extension}

      assert Validator.validate_extensions(%{"hyphen-name" => "x"}) ==
               {:error, :invalid_extension}

      assert Validator.validate_extensions(%{"" => "x"}) ==
               {:error, :invalid_extension}
    end

    test "rejects invalid extension values" do
      assert Validator.validate_extensions(%{"valid" => %{}}) == {:error, :invalid_extension}
      assert Validator.validate_extensions(%{"valid" => []}) == {:error, :invalid_extension}
    end
  end

  describe "validate_extension_name/1" do
    test "accepts valid extension names" do
      assert Validator.validate_extension_name("traceid") == true
      assert Validator.validate_extension_name("custom_attr") == true
      assert Validator.validate_extension_name("a") == true
      assert Validator.validate_extension_name("abc123_def456") == true
    end

    test "rejects invalid extension names" do
      refute Validator.validate_extension_name("")
      refute Validator.validate_extension_name("InvalidName")
      refute Validator.validate_extension_name("UPPERCASE")
      refute Validator.validate_extension_name("123abc")
      refute Validator.validate_extension_name("hyphen-name")
      refute Validator.validate_extension_name("name.with.dots")
    end
  end

  describe "validate_extension_value/1" do
    test "accepts valid extension value types" do
      assert Validator.validate_extension_value("string") == true
      assert Validator.validate_extension_value(123) == true
      assert Validator.validate_extension_value(1.5) == true
      assert Validator.validate_extension_value(true) == true
      assert Validator.validate_extension_value(false) == true
      assert Validator.validate_extension_value(nil) == true
    end

    test "rejects invalid extension value types" do
      refute Validator.validate_extension_value(%{})
      refute Validator.validate_extension_value([])
      refute Validator.validate_extension_value({:tuple})
    end
  end

  describe "all_errors/1" do
    test "returns empty list for valid event" do
      event = CloudEvent.new!(source: "/test", type: "com.test", data: %{})
      assert Validator.all_errors(event) == []
    end

    test "returns all validation errors for invalid event" do
      event = %CloudEvent{
        specversion: "2.0",
        id: "",
        source: "",
        type: "",
        data: nil,
        time: "invalid",
        datacontenttype: 123,
        extensions: %{"InvalidName" => "x"}
      }

      errors = Validator.all_errors(event)

      assert :invalid_specversion in errors
      assert :invalid_id in errors
      assert :invalid_source in errors
      assert :invalid_type in errors
      assert :invalid_time in errors
      assert :invalid_datacontenttype in errors
      assert :invalid_extension in errors
    end

    test "returns not_a_cloudevent for non-struct input" do
      assert Validator.all_errors(%{}) == [:not_a_cloudevent]
      assert Validator.all_errors(nil) == [:not_a_cloudevent]
    end

    test "returns unique errors only" do
      # An event that would produce duplicate errors if not deduplicated
      event = %CloudEvent{
        specversion: "2.0",
        id: "",
        source: "",
        type: "",
        data: nil
      }

      errors = Validator.all_errors(event)
      assert errors == Enum.uniq(errors)
    end
  end
end
