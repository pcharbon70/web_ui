defmodule WebUi.CloudEvent do
  @moduledoc """
  CloudEvent struct following CNCF CloudEvents Specification v1.0.1.

  A CloudEvent is a standardized format for event data that provides
  interoperability across services, platforms, and systems.

  ## Required Attributes

  * `specversion` - The CloudEvents specification version (always "1.0")
  * `id` - Unique identifier for the event (typically a UUID)
  * `source` - URI reference identifying the context in which an event happened
  * `type` - String identifying the type of event (e.g., "com.example.someevent")
  * `data` - Event-specific data (any valid JSON-serializable value)

  ## Optional Attributes

  * `datacontenttype` - Content type of the `data` value (defaults to "application/json")
  * `datacontentencoding` - Encoding for `data` (e.g., "base64" for binary data)
  * `subject` - Subject of the event in the context of the event producer
  * `time` - Timestamp of when the event occurred (ISO 8601 string or DateTime)
  * `extensions` - Map of additional custom attributes

  ## Example

      iex> %WebUi.CloudEvent{
      ...>   specversion: "1.0",
      ...>   id: "A234-1234-1234",
      ...>   source: "my-source",
      ...>   type: "com.example.someevent",
      ...>   data: %{message: "Hello World"}
      ...> }

      iex> WebUi.CloudEvent.new!(
      ...>   source: "my-source",
      ...>   type: "com.example.someevent",
      ...>   data: %{message: "Hello World"}
      ...> )

  ## CloudEvents Specification

  See https://github.com/cloudevents/spec/blob/v1.0.1/cloudevents/spec.md
  for the complete CloudEvents specification.

  ## Type Specification

  The `@type t()` provides Dialyzer type specifications for the struct.
  """

  @type data :: %{
    optional(atom() | String.t()) => any()
  } | [any()] | String.t() | number() | boolean() | nil

  @type extensions :: %{
    optional(String.t()) => String.t() | number() | boolean() | nil
  }

  @type t :: %__MODULE__{
    specversion: String.t(),
    id: String.t(),
    source: String.t(),
    type: String.t(),
    data: data(),
    datacontenttype: String.t() | nil,
    datacontentencoding: String.t() | nil,
    subject: String.t() | nil,
    time: String.t() | DateTime.t() | nil,
    extensions: extensions() | nil
  }

  @struct_fields [
    :specversion,
    :id,
    :source,
    :type,
    :data,
    :datacontenttype,
    :datacontentencoding,
    :subject,
    :time,
    :extensions
  ]

  @enforce_keys [:specversion, :id, :source, :type, :data]

  defstruct @struct_fields

  @doc """
  The default CloudEvents specification version supported.
  """
  @spec specversion() :: String.t()
  def specversion, do: "1.0"

  @doc """
  Creates a new CloudEvent struct.

  Automatically generates an ID and sets the specversion.
  Raises `ArgumentError` if required fields are missing or invalid.

  ## Options

  * `:source` - Required. URI reference identifying the event source
  * `:type` - Required. Event type in reverse-domain notation
  * `:data` - Required. Event-specific data
  * `:id` - Optional. Event ID (auto-generated UUID if not provided)
  * `:datacontenttype` - Optional. Content type (defaults to "application/json")
  * `:datacontentencoding` - Optional. Encoding (e.g., "base64")
  * `:subject` - Optional. Subject of the event
  * `:time` - Optional. Event timestamp (DateTime or ISO 8601 string)
  * `:extensions` - Optional. Map of custom attributes

  ## Examples

      iex> WebUi.CloudEvent.new!(
      ...>   source: "my-source",
      ...>   type: "com.example.event",
      ...>   data: %{message: "Hello"}
      ...> )

      iex> WebUi.CloudEvent.new!(
      ...>   id: "custom-id",
      ...>   source: "/mycontext",
      ...>   type: "com.example.event",
      ...>   data: nil,
      ...>   subject: "my-subject"
      ...> )

  """
  @spec new!(keyword()) :: t()
  def new!(opts) when is_list(opts) do
    source = Keyword.get(opts, :source)
    type = Keyword.get(opts, :type)
    data = Keyword.get(opts, :data)

    # Validate required fields
    validate_source!(source)
    validate_type!(type)

    # Generate ID if not provided
    id = Keyword.get(opts, :id, generate_id())

    # Build the struct
    struct!(
      __MODULE__,
      specversion: specversion(),
      id: id,
      source: source,
      type: type,
      data: data,
      datacontenttype: Keyword.get(opts, :datacontenttype),
      datacontentencoding: Keyword.get(opts, :datacontentencoding),
      subject: Keyword.get(opts, :subject),
      time: Keyword.get(opts, :time),
      extensions: Keyword.get(opts, :extensions)
    )
  end

  @doc """
  Creates a new CloudEvent struct.

  Similar to `new!/1` but returns `{:ok, event}` on success or
  `{:error, reason}` on failure instead of raising.

  ## Examples

      iex> {:ok, event} = WebUi.CloudEvent.new(
      ...>   source: "my-source",
      ...>   type: "com.example.event",
      ...>   data: %{message: "Hello"}
      ...> )
      iex> event.source
      "my-source"

      iex> WebUi.CloudEvent.new(source: nil, type: "com.example.event", data: %{})
      {:error, :validation_failed}

  """
  @spec new(keyword()) :: {:ok, t()} | {:error, atom()}
  def new(opts) when is_list(opts) do
    try do
      {:ok, new!(opts)}
    rescue
      ArgumentError -> {:error, :validation_failed}
      _ -> {:error, :unknown_error}
    end
  end

  @doc """
  Validates a CloudEvent struct.

  Returns `:ok` if the event is valid, or `{:error, reason}` if invalid.

  ## Examples

      iex> event = %WebUi.CloudEvent{
      ...>   specversion: "1.0",
      ...>   id: "123",
      ...>   source: "my-source",
      ...>   type: "com.example.event",
      ...>   data: %{}
      ...> }
      iex> WebUi.CloudEvent.validate(event)
      :ok

  """
  @spec validate(t()) :: :ok | {:error, atom()}
  def validate(%__MODULE__{} = event) do
    with :ok <- validate_specversion(event.specversion),
         :ok <- validate_id(event.id),
         :ok <- validate_source(event.source),
         :ok <- validate_type(event.type),
         :ok <- validate_datacontenttype(event.datacontenttype) do
      :ok
    end
  end

  def validate(_), do: {:error, :not_a_cloudevent}

  @doc """
  Generates a unique ID for a CloudEvent.

  Uses UUID v4 for unique identifier generation.

  ## Examples

      iex> id = WebUi.CloudEvent.generate_id()
      iex> is_binary(id) and byte_size(id) == 36
      true

  """
  @spec generate_id() :: String.t()
  def generate_id do
    Uniq.UUID.uuid4()
  end

  # Validation functions

  defp validate_specversion("1.0"), do: :ok
  defp validate_specversion(_), do: {:error, :invalid_specversion}

  defp validate_id(id) when is_binary(id) and id != "", do: :ok
  defp validate_id(_), do: {:error, :invalid_id}

  defp validate_source(source) when is_binary(source) and source != "" do
    # Check if it looks like a URI (very basic check)
    if String.starts_with?(source, ["/", "http:", "https:", "urn:", "mailto:"]) do
      :ok
    else
      # Accept non-empty strings as source (could be any URI reference)
      :ok
    end
  end
  defp validate_source(_), do: {:error, :invalid_source}

  defp validate_type(type) when is_binary(type) and type != "" do
    # Recommend reverse-domain notation but don't enforce it strictly
    # Basic check: should contain a dot or be a valid type
    if String.contains?(type, ".") or byte_size(type) > 0 do
      :ok
    else
      {:error, :invalid_type}
    end
  end
  defp validate_type(_), do: {:error, :invalid_type}

  defp validate_source!(source) do
    case validate_source(source) do
      :ok -> :ok
      {:error, :invalid_source} -> raise ArgumentError, "source must be a non-empty string"
    end
  end

  defp validate_type!(type) do
    case validate_type(type) do
      :ok -> :ok
      {:error, :invalid_type} -> raise ArgumentError, "type must be a non-empty string"
    end
  end

  defp validate_datacontenttype(nil), do: :ok
  defp validate_datacontenttype(type) when is_binary(type), do: :ok
  defp validate_datacontenttype(_), do: {:error, :invalid_datacontenttype}

  @doc """
  Creates a source URI from components.

  Useful for constructing source URIs from application context.

  ## Examples

      iex> WebUi.CloudEvent.source("my-app", "user-service")
      "urn:my-app:user-service"

      iex> WebUi.CloudEvent.source("https://example.com", "/api/events")
      "https://example.com/api/events"

  """
  @spec source(String.t(), String.t()) :: String.t()
  def source(prefix, path) when is_binary(prefix) and is_binary(path) do
    cond do
      String.starts_with?(prefix, ["http://", "https://"]) ->
        prefix <> path

      String.starts_with?(prefix, "urn:") ->
        prefix <> ":" <> String.trim_leading(path, ":")

      true ->
        "urn:" <> prefix <> ":" <> String.trim_leading(path, ":")
    end
  end

  @doc """
  Returns true if the given value is a CloudEvent struct.

  ## Examples

      iex> event = %WebUi.CloudEvent{
      ...>   specversion: "1.0",
      ...>   id: "123",
      ...>   source: "my-source",
      ...>   type: "com.example.event",
      ...>   data: %{}
      ...> }
      iex> WebUi.CloudEvent.cloudevent?(event)
      true

      iex> WebUi.CloudEvent.cloudevent?(%{})
      false

  """
  @spec cloudevent?(any()) :: boolean()
  def cloudevent?(%__MODULE__{}), do: true
  def cloudevent?(_), do: false

  # ============================================================================
  # Builder and Helper Functions
  # ============================================================================

  @doc """
  Adds the current UTC timestamp to a CloudEvent.

  Returns a new CloudEvent with the `time` field set to the current UTC time.

  ## Examples

      iex> event = WebUi.CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})
      iex> event = WebUi.CloudEvent.put_time(event)
      iex> event.time
      iex> is_binary(event.time) or match?(%DateTime{}, event.time)
      true

  """
  @spec put_time(t()) :: t()
  def put_time(%__MODULE__{} = event) do
    %{event | time: DateTime.utc_now()}
  end

  @doc """
  Sets a specific timestamp on a CloudEvent.

  Accepts either a DateTime struct or an ISO 8601 string.

  ## Examples

      iex> event = WebUi.CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})
      iex> dt = DateTime.from_iso8601("2024-01-15T12:30:45Z") |> elem(1)
      iex> event = WebUi.CloudEvent.put_time(event, dt)
      iex> event.time.year
      2024

  """
  @spec put_time(t(), DateTime.t() | String.t()) :: t()
  def put_time(%__MODULE__{} = event, %DateTime{} = dt) do
    %{event | time: dt}
  end
  def put_time(%__MODULE__{} = event, time_string) when is_binary(time_string) do
    %{event | time: time_string}
  end

  @doc """
  Generates and sets a new UUID v4 as the event ID.

  Returns a new CloudEvent with a randomly generated ID.

  ## Examples

      iex> event = %WebUi.CloudEvent{specversion: "1.0", id: "old-id", source: "/test", type: "com.test.event", data: %{}}
      iex> event = WebUi.CloudEvent.put_id(event)
      iex> byte_size(event.id)
      36

  """
  @spec put_id(t()) :: t()
  def put_id(%__MODULE__{} = event) do
    %{event | id: generate_id()}
  end

  @doc """
  Sets a specific ID on a CloudEvent.

  ## Examples

      iex> event = %WebUi.CloudEvent{specversion: "1.0", id: "old-id", source: "/test", type: "com.test.event", data: %{}}
      iex> event = WebUi.CloudEvent.put_id(event, "new-id")
      iex> event.id
      "new-id"

  """
  @spec put_id(t(), String.t()) :: t()
  def put_id(%__MODULE__{} = event, id) when is_binary(id) do
    %{event | id: id}
  end

  @doc """
  Adds or updates a custom extension attribute on a CloudEvent.

  Extensions are custom attributes not defined in the CloudEvents specification.
  This function merges the new extension with any existing extensions.

  ## Examples

      iex> event = WebUi.CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})
      iex> event = WebUi.CloudEvent.put_extension(event, "custom-attr", "custom-value")
      iex> event.extensions["custom-attr"]
      "custom-value"

      iex> event = WebUi.CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})
      iex> event = WebUi.CloudEvent.put_extension(event, "number-attr", 123)
      iex> event.extensions["number-attr"]
      123

  """
  @spec put_extension(t(), String.t(), String.t() | number() | boolean() | nil) :: t()
  def put_extension(%__MODULE__{} = event, key, value)
      when is_binary(key) and is_binary(key) and byte_size(key) > 0 do
    extensions = Map.new(event.extensions || %{})
    %{event | extensions: Map.put(extensions, key, value)}
  end

  @doc """
  Sets the subject field on a CloudEvent.

  The subject identifies the subject of the event in the context of the
  event producer.

  ## Examples

      iex> event = WebUi.CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})
      iex> event = WebUi.CloudEvent.put_subject(event, "my-subject")
      iex> event.subject
      "my-subject"

  """
  @spec put_subject(t(), String.t()) :: t()
  def put_subject(%__MODULE__{} = event, subject) when is_binary(subject) do
    %{event | subject: subject}
  end

  @doc """
  Updates the data field on a CloudEvent.

  ## Examples

      iex> event = WebUi.CloudEvent.new!(source: "/test", type: "com.test.event", data: %{old: "data"})
      iex> event = WebUi.CloudEvent.put_data(event, %{new: "data"})
      iex> event.data
      %{new: "data"}

  """
  @spec put_data(t(), data()) :: t()
  def put_data(%__MODULE__{} = event, data) do
    %{event | data: data}
  end

  @doc """
  Detects the appropriate content type for the given data.

  Returns a MIME type string based on the data structure:
  * Maps → "application/json"
  * Lists → "application/json"
  * Strings → "text/plain"
  * Numbers → "application/json"
  * Booleans → "application/json"
  * nil → "application/json"

  ## Examples

      iex> WebUi.CloudEvent.detect_data_content_type(%{key: "value"})
      "application/json"

      iex> WebUi.CloudEvent.detect_data_content_type("plain text")
      "text/plain"

  """
  @spec detect_data_content_type(data()) :: String.t()
  def detect_data_content_type(data) when is_map(data), do: "application/json"
  def detect_data_content_type(data) when is_list(data), do: "application/json"
  def detect_data_content_type(data) when is_binary(data), do: "text/plain"
  def detect_data_content_type(data) when is_number(data), do: "application/json"
  def detect_data_content_type(data) when is_boolean(data), do: "application/json"
  def detect_data_content_type(_), do: "application/json"

  # Convenience builders for common event types

  @doc """
  Creates a success event.

  Convenience builder for creating events that indicate successful operations.

  ## Options

  All options from `new!/1` are supported. The event type will be prefixed with "com.ok.".

  ## Examples

      iex> event = WebUi.CloudEvent.ok("my-app", %{result: "success"})
      iex> event.type
      "com.ok.my-app"

  """
  @spec ok(String.t(), data()) :: t()
  def ok(name, data) when is_binary(name) do
    new!(
      source: source("ok", name),
      type: "com.ok.#{name}",
      data: data,
      time: DateTime.utc_now()
    )
  end

  @doc """
  Creates an error event.

  Convenience builder for creating events that indicate errors.

  ## Options

  All options from `new!/1` are supported. The event type will be prefixed with "com.error.".

  ## Examples

      iex> event = WebUi.CloudEvent.error("validation", %{errors: ["invalid input"]})
      iex> event.type
      "com.error.validation"

  """
  @spec error(String.t(), data()) :: t()
  def error(name, data) when is_binary(name) do
    new!(
      source: source("error", name),
      type: "com.error.#{name}",
      data: data,
      time: DateTime.utc_now()
    )
  end

  @doc """
  Creates an info event.

  Convenience builder for creating informational events.

  ## Options

  All options from `new!/1` are supported. The event type will be prefixed with "com.info.".

  ## Examples

      iex> event = WebUi.CloudEvent.info("debug", %{message: "processing started"})
      iex> event.type
      "com.info.debug"

  """
  @spec info(String.t(), data()) :: t()
  def info(name, data) when is_binary(name) do
    new!(
      source: source("info", name),
      type: "com.info.#{name}",
      data: data,
      time: DateTime.utc_now()
    )
  end

  @doc """
  Creates a data changed event.

  Convenience builder for events that indicate state changes.

  ## Examples

      iex> event = WebUi.CloudEvent.data_changed("user", "123", %{status: "active"})
      iex> event.type
      "com.data_changed.user"
      iex> event.subject
      "123"

  """
  @spec data_changed(String.t(), String.t(), data()) :: t()
  def data_changed(entity_type, entity_id, data)
      when is_binary(entity_type) and is_binary(entity_id) do
    new!(
      source: source("data_changed", entity_type),
      type: "com.data_changed.#{entity_type}",
      subject: entity_id,
      data: data,
      time: DateTime.utc_now()
    )
  end

  @doc """
  Imports common CloudEvent functions when using `use WebUi.CloudEvent`.

  Automatically imports builder and helper functions for convenience.

  ## Example

      use WebUi.CloudEvent

      # Now you can call functions directly:
      event = new!(source: "/test", type: "com.test.event", data: %{})
      event = put_time(event)

  """
  def __using__(_opts \\ []) do
    quote do
      import WebUi.CloudEvent,
        only: [
          new!: 1,
          new: 1,
          validate: 1,
          generate_id: 0,
          source: 2,
          cloudevent?: 1,
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
          data_changed: 3,
          to_json: 1,
          to_json!: 1,
          from_json: 1,
          from_json!: 1,
          to_json_map: 1,
          from_json_map: 1
        ]
    end
  end

  # ============================================================================
  # JSON Encoding and Decoding
  # ============================================================================

  @doc """
  Encodes a CloudEvent struct to a JSON string.

  Returns `{:ok, json_string}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> event = %WebUi.CloudEvent{
      ...>   specversion: "1.0",
      ...>   id: "test-id",
      ...>   source: "/test/source",
      ...>   type: "com.test.event",
      ...>   data: %{message: "Hello"}
      ...> }
      iex> {:ok, json} = WebUi.CloudEvent.to_json(event)
      iex> is_binary(json)
      true

  """
  @spec to_json(t()) :: {:ok, String.t()} | {:error, any()}
  def to_json(%__MODULE__{} = event) do
    case Jason.encode(to_json_map(event)) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, {:encode_error, reason}}
    end
  end

  @doc """
  Encodes a CloudEvent struct to a JSON string.

  Similar to `to_json/1` but raises on error.

  ## Examples

      iex> event = WebUi.CloudEvent.new!(
      ...>   source: "/test",
      ...>   type: "com.test.event",
      ...>   data: %{message: "Hello"}
      ...> )
      iex> json = WebUi.CloudEvent.to_json!(event)
      iex> is_binary(json)
      true

  """
  @spec to_json!(t()) :: String.t()
  def to_json!(%__MODULE__{} = event) do
    case to_json(event) do
      {:ok, json} -> json
      {:error, reason} -> raise ArgumentError, "to_json! failed: #{inspect(reason)}"
    end
  end

  def to_json!(%{}) do
    raise ArgumentError, "to_json! failed: not a CloudEvent struct"
  end

  @doc """
  Decodes a JSON string to a CloudEvent struct.

  Returns `{:ok, event}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> json = ~s({"specversion":"1.0","id":"test","source":"/test","type":"com.test.event","data":{}})
      iex> {:ok, event} = WebUi.CloudEvent.from_json(json)
      iex> event.source
      "/test"

  """
  @spec from_json(String.t()) :: {:ok, t()} | {:error, any()}
  def from_json(json_string) when is_binary(json_string) do
    case Jason.decode(json_string) do
      {:ok, map} when is_map(map) -> from_json_map(map)
      {:error, reason} -> {:error, {:decode_error, reason}}
    end
  end

  @doc """
  Decodes a JSON string to a CloudEvent struct.

  Similar to `from_json/1` but raises on error.

  ## Examples

      iex> json = ~s({"specversion":"1.0","id":"test","source":"/test","type":"com.test.event","data":{}})
      iex> event = WebUi.CloudEvent.from_json!(json)
      iex> event.source
      "/test"

  """
  @spec from_json!(String.t()) :: t()
  def from_json!(json_string) when is_binary(json_string) do
    case from_json(json_string) do
      {:ok, event} -> event
      {:error, reason} -> raise ArgumentError, "from_json! failed: #{inspect(reason)}"
    end
  end

  @doc """
  Encodes a CloudEvent struct to a Map compatible with JSON encoding.

  This is useful when you want to embed a CloudEvent in another JSON structure.

  ## Examples

      iex> event = %WebUi.CloudEvent{
      ...>   specversion: "1.0",
      ...>   id: "test-id",
      ...>   source: "/test/source",
      ...>   type: "com.test.event",
      ...>   data: %{message: "Hello"}
      ...> }
      iex> map = WebUi.CloudEvent.to_json_map(event)
      iex> map["specversion"]
      "1.0"

  """
  @spec to_json_map(t()) :: map()
  def to_json_map(%__MODULE__{} = event) do
    %{}
    |> put_optional("specversion", event.specversion)
    |> put_optional("id", event.id)
    |> put_optional("source", event.source)
    |> put_optional("type", event.type)
    |> put_data(event.data, event.datacontentencoding)
    |> put_optional("datacontenttype", event.datacontenttype)
    |> put_optional("datacontentencoding", event.datacontentencoding)
    |> put_optional("subject", event.subject)
    |> put_optional("time", encode_time(event.time))
    |> put_extensions(event.extensions)
  end

  @doc """
  Decodes a Map to a CloudEvent struct.

  The map should have string keys as produced by JSON decoding.

  ## Examples

      iex> map = %{
      ...>   "specversion" => "1.0",
      ...>   "id" => "test-id",
      ...>   "source" => "/test/source",
      ...>   "type" => "com.test.event",
      ...>   "data" => %{"message" => "Hello"}
      ...> }
      iex> {:ok, event} = WebUi.CloudEvent.from_json_map(map)
      iex> event.data
      %{"message" => "Hello"}

  """
  @spec from_json_map(map()) :: {:ok, t()} | {:error, any()}
  def from_json_map(map) when is_map(map) do
    with :ok <- validate_specversion(Map.get(map, "specversion")),
         :ok <- validate_required_field(map, "id"),
         :ok <- validate_required_field(map, "source"),
         :ok <- validate_required_field(map, "type"),
         :ok <- validate_required_field(map, "data") do
      # Handle data_base64 encoding
      {data, datacontentencoding} = decode_data(map)

      event = %__MODULE__{
        specversion: Map.get(map, "specversion", "1.0"),
        id: Map.get(map, "id"),
        source: Map.get(map, "source"),
        type: Map.get(map, "type"),
        data: data,
        datacontenttype: Map.get(map, "datacontenttype"),
        datacontentencoding: datacontentencoding,
        subject: Map.get(map, "subject"),
        time: decode_time(Map.get(map, "time")),
        extensions: extract_extensions(map)
      }

      {:ok, event}
    end
  end

  # Private helper functions for JSON encoding/decoding

  defp put_optional(map, _key, nil), do: map
  defp put_optional(map, key, value), do: Map.put(map, key, value)

  defp put_data(map, data, encoding) do
    case encoding do
      "base64" ->
        case encode_data_base64(data) do
          {:ok, encoded} -> Map.put(map, "data_base64", encoded)
          {:error, _} -> Map.put(map, "data", data)
        end

      _ ->
        Map.put(map, "data", data)
    end
  end

  defp put_extensions(map, nil), do: map
  defp put_extensions(map, extensions) when is_map(extensions) do
    Enum.reduce(extensions, map, fn {key, value}, acc ->
      Map.put(acc, key, value)
    end)
  end
  defp put_extensions(map, _), do: map

  defp encode_time(nil), do: nil
  defp encode_time(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp encode_time({:ok, %DateTime{} = dt}), do: DateTime.to_iso8601(dt)
  defp encode_time(time) when is_binary(time), do: time

  defp decode_time(nil), do: nil
  defp decode_time("") do
    # Empty string means nil
    nil
  end
  defp decode_time(time_string) when is_binary(time_string) do
    case DateTime.from_iso8601(time_string) do
      {:ok, dt, _} -> dt
      {:error, _} -> time_string  # Keep as string if not valid ISO 8601
    end
  end

  defp decode_data(map) do
    encoding = Map.get(map, "datacontentencoding")

    cond do
      encoding == "base64" ->
        case Map.get(map, "data_base64") do
          nil -> {Map.get(map, "data"), encoding}
          encoded ->
            case decode_data_base64(encoded) do
              {:ok, decoded} -> {decoded, encoding}
              {:error, _} -> {Map.get(map, "data"), encoding}
            end
        end

      Map.has_key?(map, "data_base64") ->
        # data_base64 present but encoding not set to base64
        # Try to decode anyway
        case decode_data_base64(Map.get(map, "data_base64")) do
          {:ok, decoded} -> {decoded, "base64"}
          {:error, _} -> {Map.get(map, "data"), encoding}
        end

      true ->
        {Map.get(map, "data"), encoding}
    end
  end

  defp encode_data_base64(data) when is_binary(data) do
    try do
      {:ok, Base.encode64(data)}
    rescue
      _ -> {:error, :encode_failed}
    end
  end
  defp encode_data_base64(data) do
    # For non-binary data, encode as JSON then base64
    case Jason.encode(data) do
      {:ok, json} -> {:ok, Base.encode64(json)}
      {:error, _} -> {:error, :encode_failed}
    end
  end

  defp decode_data_base64(encoded) when is_binary(encoded) do
    try do
      case Base.decode64(encoded) do
        {:ok, decoded} ->
          # Try to decode as JSON first
          case Jason.decode(decoded) do
            {:ok, parsed} -> {:ok, parsed}
            {:error, _} -> {:ok, decoded}  # Return raw binary if not JSON
          end

        :error ->
          {:error, :invalid_base64}
      end
    rescue
      _ -> {:error, :decode_failed}
    end
  end

  defp validate_required_field(map, "data") do
    # data field is required but can be nil
    # data_base64 can be used instead of data when using base64 encoding
    if Map.has_key?(map, "data") or Map.has_key?(map, "data_base64") do
      :ok
    else
      {:error, {:missing_field, "data"}}
    end
  end

  defp validate_required_field(map, key) do
    if Map.has_key?(map, key) and Map.get(map, key) != nil do
      :ok
    else
      {:error, {:missing_field, key}}
    end
  end

  defp extract_extensions(map) do
    # CloudEvents extensions are any attribute not in the spec
    # Spec attributes are: specversion, id, source, type, datacontenttype,
    # datacontentencoding, subject, time, data, data_base64
    spec_attributes = MapSet.new([
      "specversion", "id", "source", "type",
      "datacontenttype", "datacontentencoding", "subject", "time",
      "data", "data_base64"
    ])

    map
    |> Enum.reject(fn {k, _} -> MapSet.member?(spec_attributes, k) end)
    |> Map.new()
    |> case do
      ext when map_size(ext) > 0 -> ext
      _ -> nil
    end
  end
end
