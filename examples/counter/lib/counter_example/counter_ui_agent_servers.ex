defmodule CounterExample.CounterUiAgentServers do
  @moduledoc """
  Child specs and identifiers for per-command counter UI agent servers.
  """

  alias CounterExample.{CounterCommandAction, CounterUiAgent, EventContract}
  alias Jido.Instruction

  @increment_server_id "counter-ui-increment"
  @decrement_server_id "counter-ui-decrement"
  @reset_server_id "counter-ui-reset"
  @sync_server_id "counter-ui-sync"

  @server_ids [
    @increment_server_id,
    @decrement_server_id,
    @reset_server_id,
    @sync_server_id
  ]

  @spec server_ids() :: [String.t()]
  def server_ids, do: @server_ids

  @spec increment_server_id() :: String.t()
  def increment_server_id, do: @increment_server_id

  @spec decrement_server_id() :: String.t()
  def decrement_server_id, do: @decrement_server_id

  @spec reset_server_id() :: String.t()
  def reset_server_id, do: @reset_server_id

  @spec sync_server_id() :: String.t()
  def sync_server_id, do: @sync_server_id

  @spec child_specs(module()) :: [Supervisor.child_spec()]
  def child_specs(registry \\ WebUi.Registry) do
    [
      build_child_spec(@increment_server_id, registry, :increment),
      build_child_spec(@decrement_server_id, registry, :decrement),
      build_child_spec(@reset_server_id, registry, :reset),
      build_child_spec(@sync_server_id, registry, :sync)
    ]
  end

  defp build_child_spec(server_id, registry, operation) do
    command_type = command_type_for_operation!(operation)

    instruction =
      Instruction.new!(action: CounterCommandAction, params: %{operation: operation})

    %{
      id: {:counter_ui_agent_server, server_id},
      start:
        {CounterUiAgent, :start_link,
         [[id: server_id, registry: registry, routes: [{command_type, instruction}]]]}
    }
  end

  defp command_type_for_operation!(operation) do
    case EventContract.command_type_for_operation(operation) do
      {:ok, command_type} ->
        command_type

      :error ->
        raise ArgumentError,
              "unsupported counter operation for command route: #{inspect(operation)}"
    end
  end
end
