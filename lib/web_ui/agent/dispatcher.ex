defmodule WebUi.Agent.Dispatcher do
  @moduledoc """
  Bridge between the event dispatcher and the agent system.

  The AgentDispatcher routes CloudEvents from the dispatcher to registered
  agents based on their event type subscriptions. It supports both async
  (cast) and sync (callback) dispatching, handles failures, and emits telemetry.

  ## Features

  * Route events to agents based on event type subscriptions
  * Support for async (fire-and-forget) and sync (callback response) dispatching
  * Handle individual agent failures without stopping dispatch
  * Backpressure mechanism to prevent event flooding
  * Telemetry for monitoring and observability

  ## Examples

      # Dispatch an event to all matching agents (async)
      :ok = WebUi.Agent.Dispatcher.dispatch(event)

      # Dispatch with response callback (sync-like)
      :ok = WebUi.Agent.Dispatcher.dispatch(event,
        on_response: fn results -> IO.inspect(results) end
      )

      # Dispatch with timeout
      :ok = WebUi.Agent.Dispatcher.dispatch(event, timeout: 1000)

  ## Dispatch Modes

  * **Async (cast)**: Fire-and-forget, returns immediately
  * **With Callback**: Collects responses and calls the callback function

  ## Telemetry Events

  * `[:web_ui, :agent_dispatcher, :dispatch_start]` - Dispatch started
  * `[:web_ui, :agent_dispatcher, :dispatch_complete]` - Dispatch completed
  * `[:web_ui, :agent_dispatcher, :agent_result]` - Individual agent result
  * `[:web_ui, :agent_dispatcher, :agent_timeout]` - Agent timeout
  * `[:web_ui, :agent_dispatcher, :backpressure_applied]` - Backpressure triggered

  """

  use GenServer
  require Logger

  alias WebUi.CloudEvent
  alias WebUi.Agent.Registry

  @default_timeout 5000
  @max_pending 1000
  @backpressure_threshold 500

  @type event :: CloudEvent.t()
  @type agent_pid :: pid()
  @type on_response :: ([{agent_pid(), term()}] -> any())

  # Client API

  @doc """
  Starts the agent dispatcher.

  ## Options

  * `:name` - The name to register the GenServer (default: __MODULE__)
  * `:default_timeout` - Default timeout for agent delivery (default: 5000ms)
  * `:telemetry_enabled` - Whether to emit telemetry events (default: true)
  * `:max_pending` - Maximum pending responses before backpressure (default: 1000)
  * `:backpressure_threshold` - Threshold for applying backpressure (default: 500)

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Dispatches an event to matching agents.

  By default, this is async (fire-and-forget). With the `:on_response` option,
  responses will be collected and the callback function invoked with results.

  ## Options

  * `:on_response` - Optional callback function to receive agent responses
  * `:timeout` - Maximum time to wait for agent delivery (default: 5000ms)
  * `:mode` - `:async` for fire-and-forget, `:sync` to wait for all agents (default: :async)

  ## Examples

      # Async dispatch
      :ok = WebUi.Agent.Dispatcher.dispatch(event)

      # With response callback
      :ok = WebUi.Agent.Dispatcher.dispatch(event,
        on_response: fn results -> IO.inspect(results) end
      )

      # Sync mode - waits for all agents to acknowledge
      :ok = WebUi.Agent.Dispatcher.dispatch(event, mode: :sync)

  """
  @spec dispatch(event(), keyword()) :: :ok
  def dispatch(%CloudEvent{} = event, opts \\ []) do
    on_response = Keyword.get(opts, :on_response)
    mode = Keyword.get(opts, :mode, :async)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    case on_response do
      nil when mode == :async ->
        # Pure async fire-and-forget
        GenServer.cast(__MODULE__, {:dispatch, event})

      nil when mode == :sync ->
        # Sync mode - wait for all agents to acknowledge
        GenServer.call(__MODULE__, {:dispatch_sync, event, timeout}, timeout)

      callback when is_function(callback, 1) ->
        # With callback - collect responses asynchronously
        GenServer.cast(__MODULE__, {:dispatch_with_callback, event, callback, timeout})

      _ ->
        GenServer.cast(__MODULE__, {:dispatch, event})
    end
  end

  @doc """
  Returns the count of agents that would receive an event of the given type.

  ## Examples

      count = WebUi.Agent.Dispatcher.agent_count("com.example.event")
      # => 3

  """
  @spec agent_count(String.t()) :: non_neg_integer()
  def agent_count(event_type) do
    case Registry.lookup(event_type) do
      agents when is_list(agents) -> length(agents)
      _ -> 0
    end
  end

  @doc """
  Returns current dispatcher statistics.

  ## Examples

      stats = WebUi.Agent.Dispatcher.stats()
      # => %{pending_count: 10, total_dispatched: 1000, backpressure_active: false}

  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats, @default_timeout)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    state = %{
      default_timeout: Keyword.get(opts, :default_timeout, @default_timeout),
      telemetry_enabled: Keyword.get(opts, :telemetry_enabled, true),
      max_pending: Keyword.get(opts, :max_pending, @max_pending),
      backpressure_threshold: Keyword.get(opts, :backpressure_threshold, @backpressure_threshold),
      pending_responses: %{},
      total_dispatched: 0,
      backpressure_active: false
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:dispatch, event}, state) do
    # Check backpressure
    state = maybe_apply_backpressure(state)

    do_dispatch(event, :async, state)
    {:noreply, %{state | total_dispatched: state.total_dispatched + 1}}
  end

  def handle_cast({:dispatch_with_callback, event, callback, timeout}, state) do
    # Check backpressure
    state = maybe_apply_backpressure(state)

    spawn(fn ->
      results = dispatch_and_collect(event, timeout, state)
      callback.(results)
    end)

    {:noreply, %{state | total_dispatched: state.total_dispatched + 1}}
  end

  @impl true
  def handle_call({:dispatch_sync, event, timeout}, _from, state) do
    # Check backpressure
    state = maybe_apply_backpressure(state)

    results = dispatch_and_collect(event, timeout, state)

    {:reply, {:ok, results}, %{state | total_dispatched: state.total_dispatched + 1}}
  end

  def handle_call(:stats, _from, state) do
    stats = %{
      pending_count: map_size(state.pending_responses),
      total_dispatched: state.total_dispatched,
      backpressure_active: state.backpressure_active,
      backpressure_threshold: state.backpressure_threshold,
      max_pending: state.max_pending
    }

    {:reply, stats, state}
  end

  # Private Functions

  defp maybe_apply_backpressure(state) do
    pending_count = map_size(state.pending_responses)

    if pending_count > state.backpressure_threshold do
      # Apply backpressure - log warning and slow down
      if not state.backpressure_active do
        Logger.warning("Agent dispatcher backpressure activated",
          pending_count: pending_count,
          threshold: state.backpressure_threshold
        )

        emit_telemetry(:backpressure_applied, %{
          pending_count: pending_count,
          threshold: state.backpressure_threshold
        })
      end

      %{state | backpressure_active: true}
    else
      if state.backpressure_active and pending_count < div(state.backpressure_threshold, 2) do
        # Clear backpressure when we're well below threshold
        %{state | backpressure_active: false}
      else
        state
      end
    end
  end

  defp do_dispatch(event, mode, state) do
    event_type = event.type

    # Emit telemetry for dispatch start
    emit_telemetry(:dispatch_start, %{
      event_type: event_type,
      mode: mode
    })

    # Find matching agents
    agents = Registry.lookup(event_type)

    start_time = System.monotonic_time(:millisecond)

    # Dispatch to agents
    case mode do
      :async ->
        dispatch_async(agents, event, state)

      :sync ->
        dispatch_and_collect(event, state.default_timeout, state)
    end

    elapsed = System.monotonic_time(:millisecond) - start_time

    # Emit telemetry for dispatch complete
    emit_telemetry(:dispatch_complete, %{
      event_type: event_type,
      mode: mode,
      agent_count: length(agents),
      duration: elapsed
    })

    :ok
  end

  # Async dispatch - send to all agents without waiting
  defp dispatch_async(agents, event, state) do
    Enum.each(agents, fn {pid, _patterns} ->
      send_event_to_agent(pid, event, state)
    end)

    :ok
  end

  # Sync dispatch - wait for acknowledgments from all agents
  defp dispatch_and_collect(event, timeout, _state) do
    agents = Registry.lookup(event.type)

    # Create a request ref for tracking
    request_ref = make_ref()

    # Send requests to all agents using Task to handle failures
    tasks =
      Enum.map(agents, fn {pid, _patterns} ->
        Task.async(fn ->
          try do
            # Send the event via cast (fire and forget)
            # We're confirming delivery, not processing
            GenServer.cast(pid, {:cloudevent, event})

            emit_telemetry(:agent_result, %{
              agent_pid: pid,
              result: :delivered,
              request_ref: request_ref
            })

            {pid, :delivered}
          catch
            kind, reason ->
              emit_telemetry(:agent_result, %{
                agent_pid: pid,
                result: :error,
                reason: inspect(reason),
                kind: kind
              })

              {pid, {:error, {kind, reason}}}
          end
        end)
      end)

    # Wait for all tasks to complete
    results =
      try do
        Task.await_many(tasks, timeout)
      catch
        :exit, {:timeout, _} ->
          # Handle task timeout - return what we have
          Enum.map(tasks, fn task ->
            case Task.shutdown(task, :brutal_kill) do
              {:ok, result} -> result
              {:exit, _pid} -> nil
            end
          end)
          |> Enum.filter(& &1)
      end

    # Convert list of tuples to map
    Map.new(results)
  end

  # Send event to a single agent (async - no response expected)
  defp send_event_to_agent(pid, event, _state) do
    GenServer.cast(pid, {:cloudevent, event})
    :ok
  rescue
    error ->
      Logger.warning("Failed to send event to agent",
        pid: inspect(pid),
        error: inspect(error)
      )

      :error
  end

  defp emit_telemetry(event_name, measurements) do
    :telemetry.execute(
      [:web_ui, :agent_dispatcher, event_name],
      measurements,
      %{}
    )
  rescue
    _ -> :telemetry_not_available
  end
end
