defmodule WebUi.ServerAgents.CounterState do
  @moduledoc """
  Stateful backend process for the counter component server agent.
  """

  use GenServer

  @type operation :: :increment | :decrement | :reset | :sync

  @spec apply_operation(operation()) :: {:ok, integer()} | {:error, term()}
  def apply_operation(operation) when operation in [:increment, :decrement, :reset, :sync] do
    with :ok <- ensure_started() do
      {:ok, GenServer.call(__MODULE__, {:apply_operation, operation})}
    end
  end

  @spec current_count() :: {:ok, integer()} | {:error, term()}
  def current_count do
    with :ok <- ensure_started() do
      {:ok, GenServer.call(__MODULE__, :current_count)}
    end
  end

  @spec ensure_started() :: :ok | {:error, term()}
  def ensure_started do
    case Process.whereis(__MODULE__) do
      nil ->
        case GenServer.start_link(__MODULE__, 0, name: __MODULE__) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> {:error, reason}
        end

      _pid ->
        :ok
    end
  end

  @impl true
  def init(initial_count) when is_integer(initial_count), do: {:ok, initial_count}

  @impl true
  def handle_call(:current_count, _from, count), do: {:reply, count, count}

  def handle_call({:apply_operation, :increment}, _from, count) do
    new_count = count + 1
    {:reply, new_count, new_count}
  end

  def handle_call({:apply_operation, :decrement}, _from, count) do
    new_count = count - 1
    {:reply, new_count, new_count}
  end

  def handle_call({:apply_operation, :reset}, _from, _count), do: {:reply, 0, 0}
  def handle_call({:apply_operation, :sync}, _from, count), do: {:reply, count, count}
end
