defmodule CounterExample.CounterServer do
  @moduledoc """
  Stateful counter process for the counter example.

  This process is intentionally minimal and provides deterministic state updates
  for increment, decrement, reset, and sync operations.
  """

  use GenServer
  require Logger

  alias CounterExample.EventContract

  @type operation :: EventContract.operation()
  @default_call_timeout 5_000
  @telemetry_prefix [:counter_example, :counter_server, :operation]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    initial_count = Keyword.get(opts, :initial_count, 0)
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, initial_count, name: name)
  end

  @spec ensure_started() :: :ok | {:error, term()}
  def ensure_started do
    case Process.whereis(__MODULE__) do
      nil ->
        case start_link() do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> {:error, reason}
        end

      _pid ->
        :ok
    end
  end

  @spec apply_operation(term()) :: {:ok, integer()} | {:error, term()}
  def apply_operation(operation) do
    started_at = System.monotonic_time()

    with {:ok, normalized_operation} <- normalize_operation(operation),
         :ok <- ensure_started(),
         {:ok, count} <- safe_call({:apply_operation, normalized_operation}) do
      emit_operation_stop(started_at, normalized_operation, count)
      {:ok, count}
    else
      {:error, reason} = error ->
        emit_operation_error(started_at, operation, reason)
        error
    end
  end

  @spec current_count() :: {:ok, integer()} | {:error, term()}
  def current_count do
    with :ok <- ensure_started(),
         {:ok, count} <- safe_call(:current_count) do
      {:ok, count}
    end
  end

  @impl true
  def init(initial_count) when is_integer(initial_count) do
    {:ok, initial_count}
  end

  @impl true
  def handle_call(:current_count, _from, count) do
    {:reply, count, count}
  end

  def handle_call({:apply_operation, operation}, _from, count) do
    new_count = apply_operation_to_count(operation, count)
    {:reply, new_count, new_count}
  end

  defp normalize_operation(operation) do
    if operation in EventContract.operations() do
      {:ok, operation}
    else
      {:error, {:unsupported_operation, operation}}
    end
  end

  defp safe_call(request) do
    do_safe_call(request)
  catch
    :exit, {:noproc, _reason} ->
      with :ok <- ensure_started() do
        do_safe_call(request)
      else
        {:error, reason} -> {:error, {:server_not_started, reason}}
      end

    :exit, reason ->
      {:error, {:call_failed, reason}}
  end

  defp do_safe_call(request) do
    {:ok, GenServer.call(__MODULE__, request, @default_call_timeout)}
  end

  defp apply_operation_to_count(:increment, count), do: count + 1
  defp apply_operation_to_count(:decrement, count), do: count - 1
  defp apply_operation_to_count(:reset, _count), do: 0
  defp apply_operation_to_count(:sync, count), do: count

  defp emit_operation_stop(started_at, operation, count) do
    duration = System.monotonic_time() - started_at

    :telemetry.execute(
      @telemetry_prefix ++ [:stop],
      %{duration: duration},
      %{operation: operation, count: count}
    )

    Logger.info("counter_server_operation operation=#{operation} count=#{count}")
  end

  defp emit_operation_error(started_at, operation, reason) do
    duration = System.monotonic_time() - started_at

    :telemetry.execute(
      @telemetry_prefix ++ [:error],
      %{duration: duration},
      %{operation: operation, reason: reason}
    )

    Logger.warning(
      "counter_server_error operation=#{inspect(operation)} reason=#{inspect(reason)}"
    )
  end

  @doc """
  Compatibility helper retained for existing call sites.
  """
  @spec apply_operation!(operation()) :: integer()
  def apply_operation!(operation) do
    case apply_operation(operation) do
      {:ok, count} -> count
      {:error, reason} -> raise "counter server operation failed: #{inspect(reason)}"
    end
  end

  @doc """
  Compatibility helper retained for existing call sites.
  """
  @spec current_count!() :: integer()
  def current_count! do
    case current_count() do
      {:ok, count} -> count
      {:error, reason} -> raise "counter server current_count failed: #{inspect(reason)}"
    end
  end

  @doc """
  Resets the counter and returns the resulting count.
  """
  @spec reset() :: {:ok, integer()} | {:error, term()}
  def reset do
    apply_operation(:reset)
  end

  @doc """
  Returns the current count without changing state.
  """
  @spec sync() :: {:ok, integer()} | {:error, term()}
  def sync do
    apply_operation(:sync)
  end
end
