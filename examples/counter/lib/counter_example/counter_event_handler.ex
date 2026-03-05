defmodule CounterExample.CounterEventHandler do
  @moduledoc """
  Compatibility callback for the legacy `event_handler` path.

  The canonical runtime path is now server-agent dispatch via
  `CounterExample.CounterAgent`.
  """

  alias CounterExample.{CounterAgent, EventContract}
  alias WebUi.SignalBridge

  @spec handle_cloudevent(map(), Phoenix.Socket.t()) ::
          :unhandled | {:ok, map()} | {:error, term()}
  def handle_cloudevent(%{"specversion" => specversion} = incoming_event, _socket) do
    with true <- EventContract.supported_specversion?(specversion),
         {:ok, signal} <- SignalBridge.from_cloudevent_map(incoming_event) do
      case CounterAgent.handle_signal(signal) do
        :unhandled ->
          :unhandled

        {:ok, generated_signals} ->
          response =
            generated_signals
            |> normalize_generated_response()
            |> maybe_drop_generated_correlation_id(incoming_event["id"])

          {:ok, response}

        {:error, reason} ->
          {:error, reason}
      end
    else
      false ->
        :unhandled

      {:error, _reason} ->
        :unhandled
    end
  end

  def handle_cloudevent(_incoming_event, _socket), do: :unhandled

  defp normalize_generated_response(generated_signals) do
    generated_signals
    |> List.wrap()
    |> Enum.map(&SignalBridge.to_cloudevent_map/1)
    |> then(fn
      [single_event] -> single_event
      many_events -> many_events
    end)
  end

  defp maybe_drop_generated_correlation_id(response, correlation_id)
       when is_binary(correlation_id),
       do: response

  defp maybe_drop_generated_correlation_id(response, _correlation_id) when is_map(response) do
    drop_correlation_id(response)
  end

  defp maybe_drop_generated_correlation_id(response, _correlation_id) when is_list(response) do
    Enum.map(response, &drop_correlation_id/1)
  end

  defp drop_correlation_id(%{"data" => data} = response) when is_map(data) do
    Map.put(response, "data", Map.delete(data, "correlation_id"))
  end

  defp drop_correlation_id(response), do: response
end
