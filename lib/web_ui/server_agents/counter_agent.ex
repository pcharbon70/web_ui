defmodule WebUi.ServerAgents.CounterAgent do
  @moduledoc """
  Component server agent for counter interaction signals.
  """

  @behaviour WebUi.ComponentServerAgent

  alias Jido.Signal
  alias WebUi.ServerAgents.CounterState

  @source "urn:webui:components:counter"
  @state_changed_type "com.webui.counter.state_changed"

  @impl true
  def handles?(%Signal{type: type}) when is_binary(type) do
    match_operation(type) != :error
  end

  def handles?(_), do: false

  @impl true
  def handle_signal(%Signal{} = signal) do
    case match_operation(signal.type) do
      {:ok, operation} ->
        with {:ok, count} <- CounterState.apply_operation(operation) do
          {:ok, build_state_changed_signal(signal, count, operation)}
        end

      :error ->
        :unhandled
    end
  end

  defp match_operation("com.webui.counter.increment"), do: {:ok, :increment}
  defp match_operation("com.webui.counter.decrement"), do: {:ok, :decrement}
  defp match_operation("com.webui.counter.reset"), do: {:ok, :reset}
  defp match_operation("com.webui.counter.sync"), do: {:ok, :sync}
  defp match_operation(_), do: :error

  defp build_state_changed_signal(incoming_signal, count, operation) do
    data =
      %{
        "count" => count,
        "operation" => Atom.to_string(operation),
        "correlation_id" => incoming_signal.id
      }
      |> maybe_drop_nil_correlation(incoming_signal.id)

    Signal.new!(%{
      type: @state_changed_type,
      source: @source,
      data: data
    })
  end

  defp maybe_drop_nil_correlation(data, correlation_id) when is_binary(correlation_id), do: data

  defp maybe_drop_nil_correlation(data, _correlation_id) do
    Map.delete(data, "correlation_id")
  end
end
