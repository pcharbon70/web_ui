defmodule WebUi.CloudEvent do
  @moduledoc """
  CloudEvent envelope validation and runtime context extraction helpers.
  """

  alias WebUi.TypedError

  @required_fields [:specversion, :id, :source, :type, :data]
  @context_fields [:correlation_id, :request_id, :session_id, :client_id, :user_id, :trace_id]

  @type envelope :: map()

  @spec required_fields() :: [atom()]
  def required_fields, do: @required_fields

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

  defp valid_context_id?(value), do: is_binary(value) and String.trim(value) != ""
end
