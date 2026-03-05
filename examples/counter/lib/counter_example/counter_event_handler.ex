defmodule CounterExample.CounterEventHandler do
  @moduledoc """
  Handles counter CloudEvents and emits state change events.
  """

  alias CounterExample.{CounterServer, EventContract}

  @spec handle_cloudevent(map(), Phoenix.Socket.t()) ::
          :unhandled | {:ok, map()} | {:error, term()}
  def handle_cloudevent(%{"type" => type} = incoming_event, _socket) do
    with true <- EventContract.supported_specversion?(incoming_event["specversion"]),
         {:ok, operation} <- EventContract.operation_from_command_type(type) do
      count = CounterServer.apply_operation(operation)
      {:ok, build_state_changed_event(count, operation, incoming_event)}
    else
      false ->
        :unhandled

      :error ->
        :unhandled
    end
  end

  def handle_cloudevent(_incoming_event, _socket), do: :unhandled

  defp build_state_changed_event(count, operation, incoming_event) do
    correlation_id = incoming_event["id"]

    data =
      %{
        "count" => count,
        "operation" => Atom.to_string(operation)
      }
      |> maybe_put_correlation_id(correlation_id)

    %{
      "specversion" => EventContract.specversion(),
      "id" => next_event_id(),
      "source" => EventContract.server_source(),
      "type" => EventContract.state_changed_type(),
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
