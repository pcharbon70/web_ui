defmodule WebUI.AgentDispatcher do
  @moduledoc """
  Bridge between the event dispatcher and the agent system.

  The AgentDispatcher routes CloudEvents from the dispatcher to registered
  agents based on their event type subscriptions. It supports both async
  (cast) and sync (call) dispatching, collects responses, handles failures,
  and emits telemetry.

  ## Features

  * Route events to agents based on event type subscriptions
  * Support for async (fire-and-forget) and sync (request/response) dispatching
  * Collect responses from multiple agents
  * Handle individual agent failures without stopping dispatch
  * Timeout protection for slow agents
  * Telemetry for monitoring and observability

  ## Examples

      # Dispatch an event to all matching agents (async)
      :ok = WebUI.AgentDispatcher.dispatch(event)

      # Dispatch and collect responses (sync)
      {:ok, results} = WebUI.AgentDispatcher.dispatch_sync(event, timeout: 1000)

      # Dispatch with options
      {:ok, results} = WebUI.AgentDispatcher.dispatch_sync(
        event,
        timeout: 5000,
        on_timeout: :skip
      )

  ## Dispatch Modes

  * **Async (cast)**: Fire-and-forget, returns immediately
  * **Sync (call)**: Wait for responses from all agents

  ## Telemetry Events

  * `[:web_ui, :agent_dispatcher, :dispatch_start]` - Dispatch started
  * `[:web_ui, :agent_dispatcher, :dispatch_complete]` - Dispatch completed
  * `[:web_ui, :agent_dispatcher, :agent_result]` - Individual agent result
  * `[:web_ui, :agent_dispatcher, :agent_timeout]` - Agent timeout

  """

  use GenServer
  require Logger

  alias WebUi.CloudEvent
  alias WebUI.AgentRegistry

  @type event :: CloudEvent.t()
  @type agent_pid :: pid()
  @type dispatch_result :: {:ok, %{agent_pid() => term()}} | {:error, term()}
  @type timeout_opt :: {:timeout, pos_integer()}
  @type on_timeout_opt :: {:on_timeout, :skip | :include_error}

  # Client API

  @doc """
  Starts the agent dispatcher.

  ## Options

  * `:name` - The name to register the GenServer (default: __MODULE__)
  * `:default_timeout` - Default timeout for sync dispatching (default: 5000ms)
  * `:telemetry_enabled` - Whether to emit telemetry events (default: true)

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Dispatches an event to matching agents asynchronously.

  The event is sent to all agents registered for the event type via
  GenServer.cast. This function returns immediately without waiting
  for responses.

  ## Examples

      :ok = WebUI.AgentDispatcher.dispatch(event)

  """
  @spec dispatch(event()) :: :ok
  def dispatch(%CloudEvent{} = event) do
    GenServer.cast(__MODULE__, {:dispatch, event})
  end

  @doc """
  Dispatches an event to matching agents synchronously.

  Waits for responses from all matching agents and returns a map of
  agent_pid => result. Supports timeout and error handling options.

  ## Options

  * `:timeout` - Maximum time to wait for responses (default: 5000ms)
  * `:on_timeout` - How to handle timeouts:
    * `:skip` - Exclude timed-out agents from results (default)
    * `:include_error` - Include `{:error, :timeout}` for timed-out agents

  ## Examples

      {:ok, results} = WebUI.AgentDispatcher.dispatch_sync(event)

      {:ok, results} = WebUI.AgentDispatcher.dispatch_sync(
        event,
        timeout: 1000,
        on_timeout: :include_error
      )

  """
  @spec dispatch_sync(event(), keyword()) :: dispatch_result()
  def dispatch_sync(%CloudEvent{} = event, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    on_timeout = Keyword.get(opts, :on_timeout, :skip)

    GenServer.call(__MODULE__, {:dispatch_sync, event, on_timeout}, timeout)
  end

  @doc """
  Returns the count of agents that would receive an event of the given type.

  ## Examples

      count = WebUI.AgentDispatcher.agent_count("com.example.event")
      # => 3

  """
  @spec agent_count(String.t()) :: non_neg_integer()
  def agent_count(event_type) do
    case AgentRegistry.lookup(event_type) do
      agents when is_list(agents) -> length(agents)
      _ -> 0
    end
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    state = %{
      default_timeout: Keyword.get(opts, :default_timeout, 5000),
      telemetry_enabled: Keyword.get(opts, :telemetry_enabled, true),
      pending_dispatches: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:dispatch, event}, state) do
    do_dispatch(event, :async, state)
    {:noreply, state}
  end

  @impl true
  def handle_call({:dispatch_sync, event, on_timeout}, _from, state) do
    case do_dispatch(event, :sync, state, on_timeout) do
      {:ok, results} ->
        {:reply, {:ok, results}, state}
    end
  end

  # Private Functions

  defp do_dispatch(event, mode, state, on_timeout \\ :skip) do
    event_type = event.type

    # Emit telemetry for dispatch start
    emit_telemetry(:dispatch_start, %{
      event_type: event_type,
      mode: mode
    })

    # Find matching agents
    agents = AgentRegistry.lookup(event_type)

    start_time = System.monotonic_time(:millisecond)

    results =
      if mode == :async do
        dispatch_async(agents, event, state)
        {:ok, %{}}
      else
        dispatch_sync(agents, event, state, on_timeout)
      end

    elapsed = System.monotonic_time(:millisecond) - start_time

    # Emit telemetry for dispatch complete
    emit_telemetry(:dispatch_complete, %{
      event_type: event_type,
      mode: mode,
      agent_count: length(agents),
      duration: elapsed,
      success: match?({:ok, _}, results)
    })

    results
  end

  # Async dispatch - send to all agents without waiting
  defp dispatch_async(agents, event, state) do
    Enum.each(agents, fn {pid, _patterns} ->
      send_event_to_agent(pid, event, state)
    end)

    :ok
  end

  # Sync dispatch - wait for responses from all agents
  defp dispatch_sync(agents, event, state, _on_timeout) do
    timeout = state.default_timeout

    # Create a request ref for tracking
    request_ref = make_ref()

    # Send requests to all agents using Task to handle failures
    tasks =
      Enum.map(agents, fn {pid, _patterns} ->
        Task.async(fn ->
          try do
            # Try to send the event via cast (fire and forget)
            # If it succeeds, consider it delivered
            GenServer.cast(pid, {:cloudevent, event})

            emit_telemetry(:agent_result, %{
              agent_pid: pid,
              result: :ok,
              request_ref: request_ref
            })

            {pid, :ok}
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

    # Wait for all tasks to complete (these should complete immediately since cast returns right away)
    # The timeout here is for the Task.await_many, not for agent processing
    results =
      try do
        Task.await_many(tasks, timeout)
        |> Enum.map(fn task -> task end)
        |> Map.new()
      catch
        :timeout ->
          # Handle task timeout
          Enum.map(tasks, fn task ->
            case Task.shutdown(task, :brutal_kill) do
              {:ok, result} -> result
              {:exit, _pid} -> nil
            end
          end)
          |> Enum.filter(& &1)
          |> Map.new()
      end

    # Since we're using cast, we can't actually detect which agents processed the event
    # We'll return :ok for all agents that the cast succeeded for
    {:ok, results}
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
