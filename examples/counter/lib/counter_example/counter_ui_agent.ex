defmodule CounterExample.CounterUiAgent do
  @moduledoc """
  Jido agent module used by per-command UI agent servers.
  """

  use Jido.Agent,
    name: "counter_ui_agent",
    description: "Counter UI command agent",
    schema: [],
    actions: [CounterExample.CounterCommandAction]

  alias CounterExample.EventContract
  alias Jido.Signal

  @impl true
  def transform_result(%Signal{} = signal, result, _agent) when is_map(result) do
    count = Map.get(result, :count, Map.get(result, "count"))
    operation = Map.get(result, :operation, Map.get(result, "operation"))

    response =
      Signal.new!(%{
        type: EventContract.state_changed_type(),
        source: EventContract.server_source(),
        data:
          %{
            "count" => count,
            "operation" => operation
          }
          |> maybe_put_correlation_id(signal.id)
      })

    {:ok, response}
  end

  def transform_result(_signal, result, _agent), do: {:ok, result}

  defp maybe_put_correlation_id(data, correlation_id) when is_binary(correlation_id) do
    Map.put(data, "correlation_id", correlation_id)
  end

  defp maybe_put_correlation_id(data, _correlation_id), do: data
end
