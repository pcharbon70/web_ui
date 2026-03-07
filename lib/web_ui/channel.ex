defmodule WebUi.Channel do
  @moduledoc """
  Stateless orchestration boundary for canonical websocket ingress and egress.
  """

  alias WebUi.CloudEvent
  alias WebUi.Transport.Naming
  alias WebUi.TypedError

  @send_event "runtime.event.send.v1"
  @ping_event "runtime.event.ping.v1"

  @recv_event "runtime.event.recv.v1"
  @error_event "runtime.event.error.v1"
  @pong_event "runtime.event.pong.v1"

  @spec handle_client_message(String.t(), String.t(), map()) :: {:ok, map()}
  def handle_client_message(topic, event_name, payload) do
    with :ok <- Naming.validate_topic(topic),
         :ok <- Naming.validate_client_event_name(event_name) do
      do_handle_event(event_name, payload)
    else
      {:error, %TypedError{} = error} ->
        {:ok, error_envelope(error)}
    end
  end

  defp do_handle_event(@send_event, payload) do
    with {:ok, normalized} <- normalize_ingress_payload(payload) do
      {:ok,
       %{
         event_name: @recv_event,
         payload: %{
           event: normalized.event,
           context: normalized.context
         }
       }}
    else
      {:error, %TypedError{} = error} ->
        {:ok, error_envelope(error)}
    end
  end

  defp do_handle_event(@ping_event, payload) do
    {:ok,
     %{
       event_name: @pong_event,
       payload: %{
         correlation_id: fetch_payload_value(payload, :correlation_id) || "ping",
         request_id: fetch_payload_value(payload, :request_id) || "ping"
       }
     }}
  end

  defp normalize_ingress_payload(payload) when is_map(payload) do
    with {:ok, event} <- fetch_event(payload),
         {:ok, validated_event} <- CloudEvent.validate_envelope(event),
         {:ok, context} <- CloudEvent.extract_context(validated_event) do
      {:ok, %{event: validated_event, context: context}}
    end
  end

  defp normalize_ingress_payload(_payload) do
    {:error,
     TypedError.new(
       "channel.invalid_payload",
       "protocol",
       false,
       %{reason: "payload must be a map"}
     )}
  end

  defp fetch_event(payload) do
    case fetch_payload_value(payload, :event) do
      event when is_map(event) -> {:ok, event}
      _ ->
        {:error,
         TypedError.new(
           "channel.missing_event_payload",
           "protocol",
           false,
           %{required_key: :event}
         )}
    end
  end

  defp fetch_payload_value(payload, key) when is_map(payload) do
    Map.get(payload, key) || Map.get(payload, Atom.to_string(key))
  end

  defp error_envelope(%TypedError{} = error) do
    %{
      event_name: @error_event,
      payload: %{
        error: %{
          error_code: error.error_code,
          category: error.category,
          retryable: error.retryable,
          details: error.details,
          correlation_id: error.correlation_id
        }
      }
    }
  end
end
