defmodule CounterExample.CounterEventHandler do
  @moduledoc """
  Handles counter CloudEvents and emits state change events.
  """

  @source "urn:webui:examples:counter"
  @state_changed_type "com.webui.counter.state_changed"

  @spec handle_cloudevent(map(), Phoenix.Socket.t()) ::
          :unhandled | {:ok, map()} | {:error, term()}
  def handle_cloudevent(%{"type" => type} = incoming_event, _socket) do
    case map_operation(type) do
      {:ok, operation} ->
        count = CounterExample.CounterServer.apply_operation(operation)
        {:ok, build_state_changed_event(count, operation, incoming_event)}

      :error ->
        :unhandled
    end
  end

  def handle_cloudevent(_incoming_event, _socket), do: :unhandled

  defp map_operation("com.webui.counter.increment"), do: {:ok, :increment}
  defp map_operation("com.webui.counter.decrement"), do: {:ok, :decrement}
  defp map_operation("com.webui.counter.reset"), do: {:ok, :reset}
  defp map_operation("com.webui.counter.sync"), do: {:ok, :sync}
  defp map_operation(_), do: :error

  defp build_state_changed_event(count, operation, incoming_event) do
    correlation_id = incoming_event["id"]

    data =
      %{
        "count" => count,
        "operation" => Atom.to_string(operation)
      }
      |> maybe_put_correlation_id(correlation_id)

    %{
      "specversion" => "1.0",
      "id" => next_event_id(),
      "source" => @source,
      "type" => @state_changed_type,
      "time" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "data" => data
    }
  end

  defp maybe_put_correlation_id(data, correlation_id) when is_binary(correlation_id) do
    Map.put(data, "correlation_id", correlation_id)
  end

  defp maybe_put_correlation_id(data, _), do: data

  defp next_event_id do
    "counter-" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
  end
end
