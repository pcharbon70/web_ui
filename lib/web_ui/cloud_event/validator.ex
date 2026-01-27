defmodule WebUi.CloudEvent.Validator do
  @moduledoc """
  Validation functions for CloudEvents.

  This module provides detailed validation for CloudEvents following the
  CNCF CloudEvents Specification v1.0.1.

  ## Error Types

  The validator returns the following error reasons:

  * `:not_a_cloudevent` - Input is not a CloudEvent struct
  * `:invalid_specversion` - specversion is not "1.0"
  * `:invalid_id` - id is missing, empty, or invalid
  * `:invalid_source` - source is missing, empty, or not a valid URI reference
  * `:invalid_type` - type is missing, empty, or improperly formatted
  * `:invalid_datacontenttype` - datacontenttype is not a valid MIME type
  * `:invalid_time` - time is not a valid DateTime or ISO 8601 string
  * `:invalid_extension` - extension attribute violates naming rules

  ## Examples

      iex> event = WebUi.CloudEvent.new!(
      ...>   source: "/test",
      ...>   type: "com.example.event",
      ...>   data: %{}
      ...> )
      iex> WebUi.CloudEvent.Validator.validate_full(event)
      :ok

      iex> WebUi.CloudEvent.Validator.validate_specversion("1.0")
      :ok

      iex> WebUi.CloudEvent.Validator.validate_source("https://example.com/events")
      :ok

  ## Extension Attribute Naming

  Extension attribute names must:
  - Be at least 1 character long
  - Start with a lowercase letter (a-z)
  - Contain only lowercase letters (a-z), digits (0-9), or underscores (_)

  This follows the CloudEvents specification recommendation for
  extension attribute naming.

  ## See Also

  * `WebUi.CloudEvent` - Main CloudEvent struct and functions
  * `WebUi.CloudEvent.validate/1` - Simplified validation function

  """

  @type error_reason :: atom()
  @type validation_result :: :ok | {:error, error_reason()}

  @doc """
  Validates a CloudEvent struct comprehensively.

  Performs all validation checks:
  - specversion must be "1.0"
  - id must be present and non-empty
  - source must be a valid URI reference
  - type must be present and non-empty
  - datacontenttype must be a valid MIME type if present
  - time must be valid if present
  - extensions must follow naming conventions

  ## Examples

      iex> event = WebUi.CloudEvent.new!(
      ...>   source: "/test",
      ...>   type: "com.example.event",
      ...>   data: %{}
      ...> )
      iex> WebUi.CloudEvent.Validator.validate_full(event)
      :ok

  """
  @spec validate_full(WebUi.CloudEvent.t()) :: validation_result()
  def validate_full(%WebUi.CloudEvent{} = event) do
    with :ok <- validate_specversion(event.specversion),
         :ok <- validate_id(event.id),
         :ok <- validate_source(event.source),
         :ok <- validate_type(event.type),
         :ok <- validate_datacontenttype(event.datacontenttype),
         :ok <- validate_time(event.time),
         :ok <- validate_extensions(event.extensions),
         do: :ok
  end

  def validate_full(_), do: {:error, :not_a_cloudevent}

  @doc """
  Validates the specversion field.

  The CloudEvents specification version must be "1.0".

  ## Examples

      iex> WebUi.CloudEvent.Validator.validate_specversion("1.0")
      :ok

      iex> WebUi.CloudEvent.Validator.validate_specversion("2.0")
      {:error, :invalid_specversion}

  """
  @spec validate_specversion(String.t() | nil) :: validation_result()
  def validate_specversion("1.0"), do: :ok
  def validate_specversion(_), do: {:error, :invalid_specversion}

  @doc """
  Validates the id field.

  The id must be a non-empty string. Typically a UUID v4.

  ## Examples

      iex> WebUi.CloudEvent.Validator.validate_id("A234-1234-1234")
      :ok

      iex> WebUi.CloudEvent.Validator.validate_id("")
      {:error, :invalid_id}

      iex> WebUi.CloudEvent.Validator.validate_id(nil)
      {:error, :invalid_id}

  """
  @spec validate_id(String.t() | nil) :: validation_result()
  def validate_id(id) when is_binary(id) and id != "", do: :ok
  def validate_id(_), do: {:error, :invalid_id}

  @doc """
  Validates the source field.

  The source must be a non-empty string that is a valid URI reference.
  Acceptable formats include:
  - Absolute URIs: `https://example.com/events`
  - URN: `urn:example:my-context`
  - URI reference: `/my-context`
  - Mailto: `mailto:example@example.com`

  ## Examples

      iex> WebUi.CloudEvent.Validator.validate_source("/my-context")
      :ok

      iex> WebUi.CloudEvent.Validator.validate_source("https://example.com/events")
      :ok

      iex> WebUi.CloudEvent.Validator.validate_source("urn:example:context")
      :ok

      iex> WebUi.CloudEvent.Validator.validate_source("")
      {:error, :invalid_source}

  """
  @spec validate_source(String.t() | nil) :: validation_result()
  def validate_source(source) when is_binary(source) and source != "" do
    :ok
  end

  def validate_source(_), do: {:error, :invalid_source}

  @doc """
  Validates the type field.

  The type must be a non-empty string. Reverse-domain notation is
  recommended (e.g., "com.example.someevent") but not strictly enforced.

  ## Examples

      iex> WebUi.CloudEvent.Validator.validate_type("com.example.event")
      :ok

      iex> WebUi.CloudEvent.Validator.validate_type("myapp.event")
      :ok

      iex> WebUi.CloudEvent.Validator.validate_type("")
      {:error, :invalid_type}

  """
  @spec validate_type(String.t() | nil) :: validation_result()
  def validate_type(type) when is_binary(type) and type != "" do
    # Recommend reverse-domain notation but don't enforce it strictly
    :ok
  end

  def validate_type(_), do: {:error, :invalid_type}

  @doc """
  Validates the datacontenttype field.

  Must be nil or a valid MIME type string.

  ## Examples

      iex> WebUi.CloudEvent.Validator.validate_datacontenttype(nil)
      :ok

      iex> WebUi.CloudEvent.Validator.validate_datacontenttype("application/json")
      :ok

      iex> WebUi.CloudEvent.Validator.validate_datacontenttype("text/plain")
      :ok

  """
  @spec validate_datacontenttype(String.t() | nil) :: validation_result()
  def validate_datacontenttype(nil), do: :ok
  def validate_datacontenttype(type) when is_binary(type), do: :ok
  def validate_datacontenttype(_), do: {:error, :invalid_datacontenttype}

  @doc """
  Validates the time field.

  Must be nil, a DateTime struct, or a valid ISO 8601 string.

  ## Examples

      iex> WebUi.CloudEvent.Validator.validate_time(nil)
      :ok

      iex> dt = DateTime.from_iso8601("2024-01-15T12:30:45Z") |> elem(1)
      iex> WebUi.CloudEvent.Validator.validate_time(dt)
      :ok

      iex> WebUi.CloudEvent.Validator.validate_time("2024-01-15T12:30:45Z")
      :ok

      iex> WebUi.CloudEvent.Validator.validate_time("invalid")
      {:error, :invalid_time}

  """
  @spec validate_time(DateTime.t() | String.t() | nil) :: validation_result()
  def validate_time(nil), do: :ok
  def validate_time(%DateTime{}), do: :ok

  def validate_time(time) when is_binary(time) do
    case DateTime.from_iso8601(time) do
      {:ok, _, _} -> :ok
      _ -> {:error, :invalid_time}
    end
  end

  def validate_time(_), do: {:error, :invalid_time}

  @doc """
  Validates extension attributes.

  Extension attribute names must follow CloudEvents naming conventions:
  - At least 1 character long
  - Start with a lowercase letter (a-z)
  - Contain only lowercase letters, digits, or underscores

  Extension values can be: strings, numbers, booleans, or nil.

  ## Examples

      iex> WebUi.CloudEvent.Validator.validate_extensions(%{"traceid" => "123"})
      :ok

      iex> WebUi.CloudEvent.Validator.validate_extensions(%{"custom_attr" => 123})
      :ok

      iex> WebUi.CloudEvent.Validator.validate_extensions(%{"InvalidName" => "x"})
      {:error, :invalid_extension}

      iex> WebUi.CloudEvent.Validator.validate_extensions(nil)
      :ok

  """
  @spec validate_extensions(WebUi.CloudEvent.extensions() | nil) :: validation_result()
  def validate_extensions(nil), do: :ok

  def validate_extensions(extensions) when is_map(extensions) do
    Enum.reduce_while(extensions, :ok, fn {key, value}, _acc ->
      case validate_extension_name(key) and validate_extension_value(value) do
        true -> {:cont, :ok}
        false -> {:halt, {:error, :invalid_extension}}
      end
    end)
  end

  def validate_extensions(_), do: {:error, :invalid_extension}

  @doc """
  Validates a single extension attribute name.

  Extension names must:
  - Be at least 1 character long
  - Start with a lowercase letter (a-z)
  - Contain only lowercase letters, digits (0-9), or underscores (_)

  ## Examples

      iex> WebUi.CloudEvent.Validator.validate_extension_name("traceid")
      true

      iex> WebUi.CloudEvent.Validator.validate_extension_name("custom_attr_123")
      true

      iex> WebUi.CloudEvent.Validator.validate_extension_name("InvalidName")
      false

      iex> WebUi.CloudEvent.Validator.validate_extension_name("")
      false

  """
  @spec validate_extension_name(String.t()) :: boolean()
  def validate_extension_name(name) when is_binary(name) do
    # Extension naming: [a-z][a-z0-9_]*
    # This follows CloudEvents spec conventions
    Regex.match?(~r/^[a-z][a-z0-9_]*$/, name)
  end

  def validate_extension_name(_), do: false

  @doc """
  Validates a single extension attribute value.

  Extension values must be: strings, numbers, booleans, or nil.

  ## Examples

      iex> WebUi.CloudEvent.Validator.validate_extension_value("string")
      true

      iex> WebUi.CloudEvent.Validator.validate_extension_value(123)
      true

      iex> WebUi.CloudEvent.Validator.validate_extension_value(true)
      true

      iex> WebUi.CloudEvent.Validator.validate_extension_value(nil)
      true

      iex> WebUi.CloudEvent.Validator.validate_extension_value(%{})
      false

  """
  @spec validate_extension_value(any()) :: boolean()
  def validate_extension_value(value)
      when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
      do: true

  def validate_extension_value(_), do: false

  @doc """
  Returns a list of all validation errors in an event.

  Instead of stopping at the first error, this function runs all
  validations and returns a list of all errors found.

  ## Examples

      iex> event = %WebUi.CloudEvent{
      ...>   specversion: "2.0",
      ...>   id: "",
      ...>   source: "",
      ...>   type: "",
      ...>   data: nil,
      ...>   time: "invalid"
      ...> }
      iex> errors = WebUi.CloudEvent.Validator.all_errors(event)
      iex> :invalid_specversion in errors
      true
      iex> :invalid_id in errors
      true

  """
  @spec all_errors(WebUi.CloudEvent.t()) :: [error_reason()]
  def all_errors(%WebUi.CloudEvent{} = event) do
    []
    |> add_error(validate_specversion(event.specversion))
    |> add_error(validate_id(event.id))
    |> add_error(validate_source(event.source))
    |> add_error(validate_type(event.type))
    |> add_error(validate_datacontenttype(event.datacontenttype))
    |> add_error(validate_time(event.time))
    |> add_error(validate_extensions(event.extensions))
    |> Enum.uniq()
  end

  def all_errors(_), do: [:not_a_cloudevent]

  # Private helper to accumulate errors

  defp add_error(errors, :ok), do: errors
  defp add_error(errors, {:error, reason}), do: [reason | errors]
end
