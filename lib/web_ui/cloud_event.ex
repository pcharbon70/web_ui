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
end
