defmodule WebUi.CloudEvent do
  @moduledoc """
  CloudEvent envelope validation and runtime context extraction helpers.
  """

  alias Jido.Signal
  alias WebUi.TypedError

  @required_fields [:specversion, :id, :source, :type, :data]
  @required_extensions [:correlation_id, :request_id]
  @context_fields @required_extensions ++ [:session_id, :client_id, :user_id, :trace_id]
  @jido_specversion "1.0.2"

  @type envelope :: map()

  @spec required_fields() :: [atom()]
  def required_fields, do: @required_fields

  @spec decode(map()) :: {:ok, envelope()} | {:error, TypedError.t()}
  def decode(envelope) when is_map(envelope) do
    with {:ok, validated} <- validate_envelope(envelope),
         :ok <- validate_required_extensions(validated),
         :ok <- validate_with_jido_signal(validated) do
      {:ok, validated}
    end
  end

  def decode(_envelope) do
    {:error,
     TypedError.new(
       "cloudevent.invalid_shape",
       "protocol",
       false,
       %{reason: "envelope must be a map"}
     )}
  end

  @spec encode(map()) :: {:ok, map()} | {:error, TypedError.t()}
  def encode(envelope) when is_map(envelope) do
    with {:ok, validated} <- decode(envelope) do
      {:ok, stringify_map_keys(validated)}
    end
  end

  def encode(_envelope) do
    {:error,
     TypedError.new(
       "cloudevent.invalid_shape",
       "protocol",
       false,
       %{reason: "envelope must be a map"}
     )}
  end

  @spec validate_required_extensions(map()) :: :ok | {:error, TypedError.t()}
  def validate_required_extensions(envelope) when is_map(envelope) do
    missing = Enum.filter(@required_extensions, &(fetch_value(envelope, &1) in [nil, ""]))

    if missing == [] do
      :ok
    else
      {:error,
       TypedError.new(
         "cloudevent.missing_required_extensions",
         "protocol",
         false,
         %{missing_extensions: missing}
       )}
    end
  end

  def validate_required_extensions(_envelope) do
    {:error,
     TypedError.new(
       "cloudevent.invalid_shape",
       "protocol",
       false,
       %{reason: "envelope must be a map"}
     )}
  end

  @spec validate_envelope(map()) :: {:ok, envelope()} | {:error, TypedError.t()}
  def validate_envelope(envelope) when is_map(envelope) do
    missing = Enum.filter(@required_fields, &(fetch_value(envelope, &1) in [nil, ""]))

    if missing == [] do
      {:ok,
       Enum.reduce(@required_fields ++ @context_fields, %{}, fn key, acc ->
         case fetch_value(envelope, key) do
           nil -> acc
           value -> Map.put(acc, key, value)
         end
       end)}
    else
      {:error,
       TypedError.new(
         "cloudevent.missing_required_fields",
         "protocol",
         false,
         %{missing_fields: missing}
       )}
    end
  end

  def validate_envelope(_envelope) do
    {:error,
     TypedError.new(
       "cloudevent.invalid_shape",
       "protocol",
       false,
       %{reason: "envelope must be a map"}
     )}
  end

  @spec extract_context(envelope()) :: {:ok, map()} | {:error, TypedError.t()}
  def extract_context(envelope) when is_map(envelope) do
    correlation_id = fetch_value(envelope, :correlation_id)
    request_id = fetch_value(envelope, :request_id)

    cond do
      not valid_context_id?(correlation_id) ->
        {:error,
         TypedError.new(
           "cloudevent.missing_correlation_id",
           "validation",
           false,
           %{required_field: :correlation_id}
         )}

      not valid_context_id?(request_id) ->
        {:error,
         TypedError.new(
           "cloudevent.missing_request_id",
           "validation",
           false,
           %{required_field: :request_id}
         )}

      true ->
        {:ok,
         %{
           correlation_id: correlation_id,
           request_id: request_id,
           session_id: fetch_value(envelope, :session_id),
           client_id: fetch_value(envelope, :client_id),
           user_id: fetch_value(envelope, :user_id),
           trace_id: fetch_value(envelope, :trace_id)
         }}
    end
  end

  def extract_context(_envelope) do
    {:error,
     TypedError.new(
       "cloudevent.invalid_shape",
       "protocol",
       false,
       %{reason: "envelope must be a map"}
     )}
  end

  defp fetch_value(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp stringify_map_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), stringify_value(value)} end)
    |> Enum.into(%{})
  end

  defp stringify_value(value) when is_map(value), do: stringify_map_keys(value)
  defp stringify_value(value) when is_list(value), do: Enum.map(value, &stringify_value/1)
  defp stringify_value(value), do: value

  defp valid_context_id?(value), do: is_binary(value) and String.trim(value) != ""

  defp validate_with_jido_signal(envelope) when is_map(envelope) do
    envelope
    |> jido_parse_input()
    |> Signal.from_map()
    |> case do
      {:ok, %Signal{}} ->
        :ok

      {:error, reason} ->
        {:error,
         TypedError.new(
           "cloudevent.invalid_shape",
           "protocol",
           false,
           %{reason: to_string(reason)}
         )}
    end
  end

  defp jido_parse_input(envelope) when is_map(envelope) do
    string_envelope = stringify_map_keys(envelope)
    extension_data = jido_extension_data(string_envelope)

    string_envelope
    |> Map.drop(Enum.map(@context_fields, &to_string/1))
    |> Map.put("extensions", extension_data)
    |> Map.put("specversion", @jido_specversion)
    |> normalize_jido_required_fields()
  end

  defp jido_extension_data(envelope) when is_map(envelope) do
    Enum.reduce(@context_fields, %{}, fn key, acc ->
      string_key = to_string(key)

      case Map.get(envelope, string_key) do
        nil -> acc
        value -> Map.put(acc, string_key, value)
      end
    end)
  end

  defp normalize_jido_required_fields(envelope) when is_map(envelope) do
    envelope
    |> normalize_required_field("id")
    |> normalize_required_field("source")
    |> normalize_required_field("type")
  end

  defp normalize_required_field(envelope, field) when is_map(envelope) and is_binary(field) do
    case Map.get(envelope, field) do
      nil ->
        envelope

      value when is_binary(value) ->
        envelope

      value ->
        Map.put(envelope, field, to_string(value))
    end
  end
end
