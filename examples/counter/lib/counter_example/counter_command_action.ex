defmodule CounterExample.CounterCommandAction do
  @moduledoc """
  Jido action that applies one counter operation and returns command metadata.
  """

  use Jido.Action,
    name: "counter_command",
    description: "Apply a counter operation",
    schema: [
      operation: [
        type: :atom,
        required: true
      ]
    ]

  alias CounterExample.CounterServer

  @operations [:increment, :decrement, :reset, :sync]

  @impl true
  def run(%{operation: operation}, _context) when operation in @operations do
    case CounterServer.apply_operation(operation) do
      {:ok, count} ->
        {:ok, %{count: count, operation: Atom.to_string(operation)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def run(%{operation: operation}, _context), do: {:error, {:unsupported_operation, operation}}
end
