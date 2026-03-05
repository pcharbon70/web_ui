defmodule CounterExample.CounterAgent do
  @moduledoc """
  Counter command handler for the server-agent dispatcher path.
  """

  @behaviour WebUi.ComponentServerAgent

  require Logger

  alias CounterExample.{CounterServer, EventContract}
  alias Jido.Signal

  @telemetry_prefix [:counter_example, :counter_agent, :command]

  @impl true
  def handles?(%Signal{type: type}) when is_binary(type) do
    EventContract.operation_from_command_type(type) != :error
  end

  def handles?(_), do: false

  @impl true
  def handle_signal(%Signal{} = signal) do
    started_at = System.monotonic_time()
    correlation_id = signal.id

    try do
      with :ok <- validate_signal_data(signal.data),
           {:ok, operation} <- EventContract.operation_from_command_type(signal.type),
           {:ok, count} <- CounterServer.apply_operation(operation),
           {:ok, response_signal} <- build_state_changed_signal(count, operation, correlation_id) do
        emit_command_stop(started_at, signal.type, operation, count, correlation_id)

        Logger.info(
          "counter_command_processed " <>
            "type=#{signal.type} operation=#{operation} " <>
            "count=#{count} correlation_id=#{inspect(correlation_id)}"
        )

        {:ok, response_signal}
      else
        :error ->
          :unhandled

        {:error, reason} = error ->
          emit_command_error(started_at, signal.type, correlation_id, reason)

          Logger.warning(
            "counter_command_error " <>
              "type=#{signal.type} reason=#{inspect(reason)} " <>
              "correlation_id=#{inspect(correlation_id)}"
          )

          error
      end
    rescue
      exception ->
        reason = {:exception, exception.__struct__, Exception.message(exception)}

        emit_command_error(started_at, signal.type, signal.id, reason)

        Logger.error(
          "counter_command_exception " <>
            "type=#{signal.type} error=#{Exception.message(exception)} " <>
            "correlation_id=#{inspect(signal.id)}"
        )

        {:error, :command_processing_failed}
    end
  end

  def handle_signal(_), do: {:error, :invalid_signal}

  defp validate_signal_data(data) when is_map(data), do: :ok
  defp validate_signal_data(nil), do: :ok
  defp validate_signal_data(data), do: {:error, {:invalid_signal_data, data}}

  defp build_state_changed_signal(count, operation, correlation_id) do
    data =
      %{
        "count" => count,
        "operation" => Atom.to_string(operation)
      }
      |> maybe_put_correlation_id(correlation_id)

    {:ok,
     Signal.new!(%{
       type: EventContract.state_changed_type(),
       source: EventContract.server_source(),
       data: data
     })}
  rescue
    exception ->
      {:error, {:build_state_changed_signal_failed, Exception.message(exception)}}
  end

  defp maybe_put_correlation_id(data, correlation_id) when is_binary(correlation_id) do
    Map.put(data, "correlation_id", correlation_id)
  end

  defp maybe_put_correlation_id(data, _correlation_id), do: data

  defp emit_command_stop(started_at, type, operation, count, correlation_id) do
    duration = System.monotonic_time() - started_at

    :telemetry.execute(
      @telemetry_prefix ++ [:stop],
      %{duration: duration},
      %{
        type: type,
        operation: operation,
        count: count,
        correlation_id: correlation_id
      }
    )
  end

  defp emit_command_error(started_at, type, correlation_id, reason) do
    duration = System.monotonic_time() - started_at

    :telemetry.execute(
      @telemetry_prefix ++ [:error],
      %{duration: duration},
      %{
        type: type,
        reason: reason,
        correlation_id: correlation_id
      }
    )
  end
end
