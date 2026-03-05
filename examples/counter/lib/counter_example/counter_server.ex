defmodule CounterExample.CounterServer do
  @moduledoc """
  Stateful counter process for the counter example.

  This process is intentionally minimal and provides deterministic state updates
  for increment, decrement, reset, and sync operations.
  """

  use GenServer

  @type operation :: :increment | :decrement | :reset | :sync

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, 0, Keyword.put_new(opts, :name, __MODULE__))
  end

  @spec apply_operation(operation()) :: integer()
  def apply_operation(operation) when operation in [:increment, :decrement, :reset, :sync] do
    GenServer.call(__MODULE__, {:apply_operation, operation})
  end

  @spec current_count() :: integer()
  def current_count do
    GenServer.call(__MODULE__, :current_count)
  end

  @impl true
  def init(initial_count) when is_integer(initial_count) do
    {:ok, initial_count}
  end

  @impl true
  def handle_call(:current_count, _from, count) do
    {:reply, count, count}
  end

  def handle_call({:apply_operation, :increment}, _from, count) do
    new_count = count + 1
    {:reply, new_count, new_count}
  end

  def handle_call({:apply_operation, :decrement}, _from, count) do
    new_count = count - 1
    {:reply, new_count, new_count}
  end

  def handle_call({:apply_operation, :reset}, _from, _count) do
    {:reply, 0, 0}
  end

  def handle_call({:apply_operation, :sync}, _from, count) do
    {:reply, count, count}
  end
end
