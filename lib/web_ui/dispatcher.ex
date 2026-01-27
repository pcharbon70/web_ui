defmodule WebUi.Dispatcher do
  @moduledoc """
  Event dispatcher for routing CloudEvents to registered handlers.

  The dispatcher manages event routing from channels to handlers based on
  event type patterns, supporting wildcards, filtering, and fault tolerance.

  ## Features

  * Pattern-based subscriptions (exact match, prefix/suffix wildcards)
  * Multiple handlers per event type
  * Fault-tolerant delivery (handler failures don't crash dispatcher)
  * Telemetry integration
  * Filter functions for selective delivery

  ## Examples

  ### Subscribing to Events

      # Function handler
      {:ok, _sub_id} = WebUi.Dispatcher.subscribe("com.example.*", fn event ->
        IO.inspect(event)
        :ok
      end)

      # Module/function handler
      {:ok, _sub_id} = WebUi.Dispatcher.subscribe(
        "com.example.event",
        {MyHandler, :handle_event}
      )

      # GenServer handler
      {:ok, _sub_id} = WebUi.Dispatcher.subscribe("com.example.*", my_gen_server)

  ### Dispatching Events

      event = %WebUi.CloudEvent{
        type: "com.example.event",
        source: "/my/source",
        id: WebUi.CloudEvent.generate_id()
      }

      :ok = WebUi.Dispatcher.dispatch(event)

  ### With Filter

      {:ok, _sub_id} = WebUi.Dispatcher.subscribe(
        "com.example.*",
        handler,
        filter: fn event -> event.source != "/blocked" end
      )

  ## Configuration

  Configure in your `config/config.exs`:

      config :web_ui, WebUi.Dispatcher,
        handler_timeout: 5000,
        telemetry_enabled: true,
        max_concurrent_handlers: 100

  """

  use GenServer
  require Logger

  alias WebUi.Dispatcher.{Handler, Registry}

  @type event :: WebUi.CloudEvent.t()
  @type subscription_id :: reference()
  @type handler :: Handler.handler()
  @type pattern :: String.t()

  @default_timeout 5000

  ## Client API

  @doc """
  Starts the dispatcher.

  ## Options

  * `:name` - The name to register the GenServer (default: __MODULE__)
  * `:handler_timeout` - Timeout for handler calls (default: 5000ms)
  * `:telemetry_enabled` - Whether to emit telemetry events (default: true)

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Subscribes a handler to events matching the given pattern.

  ## Patterns

  * Exact match: `"com.example.event"`
  * Prefix wildcard: `"com.example.*"`
  * Suffix wildcard: `"*.event"`
  * Full wildcard: `"*"`

  ## Handler Types

  * `{module, function}` - Calls `module.function(event)`
  * Function - Calls `function.(event)`
  * PID - Sends cast to GenServer: `GenServer.cast(pid, {:cloudevent, event})`

  ## Options

  * `:filter` - Optional filter function. Only events returning `true` are delivered.
  * `:metadata` - Optional metadata map for tracking.

  ## Returns

  * `{:ok, subscription_id}` - Successfully subscribed
  * `{:error, reason}` - Subscription failed

  ## Examples

      # Function handler
      {:ok, sub_id} = WebUi.Dispatcher.subscribe("com.example.*", fn event ->
        Logger.debug("Received event: " <> event.type)
        :ok
      end)

      # Module/function handler
      {:ok, sub_id} = WebUi.Dispatcher.subscribe(
        "com.example.event",
        {MyHandler, :handle_event}
      )

      # GenServer handler
      {:ok, sub_id} = WebUi.Dispatcher.subscribe("com.example.*", my_pid)

      # With filter
      {:ok, sub_id} = WebUi.Dispatcher.subscribe(
        "com.example.*",
        handler,
        filter: fn %CloudEvent{source: src} -> src != "/blocked" end
      )

  """
  @spec subscribe(pattern(), handler(), keyword()) :: {:ok, subscription_id()} | {:error, term()}
  def subscribe(pattern, handler, opts \\ []) do
    Registry.subscribe(pattern, handler, opts)
  end

  @doc """
  Unsubscribes a handler using the subscription ID.

  ## Examples

      WebUi.Dispatcher.unsubscribe(subscription_id)

  """
  @spec unsubscribe(subscription_id()) :: :ok
  def unsubscribe(subscription_id) do
    Registry.unsubscribe(subscription_id)
  end

  @doc """
  Dispatches a CloudEvent to all matching handlers.

  The event is delivered to handlers subscribed to matching patterns.
  Handler failures are isolated and logged.

  ## Returns

  * `:ok` - Event was dispatched (individual handler results may vary)
  * `{:error, reason}` - Dispatch failed

  ## Examples

      event = %WebUi.CloudEvent{
        type: "com.example.event",
        source: "/my/source",
        id: WebUi.CloudEvent.generate_id()
      }

      :ok = WebUi.Dispatcher.dispatch(event)

  """
  @spec dispatch(event()) :: :ok | {:error, term()}
  def dispatch(%WebUi.CloudEvent{type: type} = event) do
    handlers = Registry.find_handlers(type)

    Logger.debug("Dispatching event",
      type: type,
      handler_count: length(handlers)
    )

    emit_telemetry(:dispatch_start, %{type: type, handler_count: length(handlers)})

    results =
      Enum.map(handlers, fn {handler, _sub_id, opts} ->
        deliver_event(handler, event, opts)
      end)

    success_count =
      Enum.count(results, fn
        :ok -> true
        {:ok, _} -> true
        _ -> false
      end)

    error_count =
      Enum.count(results, fn
        {:error, _} -> true
        _ -> false
      end)

    emit_telemetry(:dispatch_complete, %{
      type: type,
      handler_count: length(handlers),
      success_count: success_count,
      error_count: error_count
    })

    Logger.debug("Dispatch complete",
      type: type,
      success: success_count,
      errors: error_count
    )

    :ok
  end

  @doc """
  Returns the count of active subscriptions.

  ## Examples

      count = WebUi.Dispatcher.subscription_count()

  """
  @spec subscription_count() :: non_neg_integer()
  def subscription_count, do: Registry.count()

  @doc """
  Returns all subscriptions for debugging/testing.

  ## Examples

      all = WebUi.Dispatcher.subscriptions()

  """
  @spec subscriptions() :: [{pattern(), handler(), subscription_id(), keyword()}]
  def subscriptions, do: Registry.all()

  @doc """
  Clears all subscriptions (for testing).

  """
  @spec clear() :: :ok
  def clear, do: Registry.clear()

  ## Server Callbacks

  @impl true
  def init(opts) do
    # Start the registry (use a unique name based on dispatcher name if provided)
    registry_name = Keyword.get(opts, :registry_name, Registry)

    # Try to start registry, or connect to existing one
    case Registry.start_link(name: registry_name) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, _} ->
        # If we can't start or connect, that's okay - we'll handle it at call time
        :ok
    end

    state = %{
      handler_timeout: Keyword.get(opts, :handler_timeout, @default_timeout),
      telemetry_enabled: Keyword.get(opts, :telemetry_enabled, true),
      registry_name: registry_name
    }

    {:ok, state}
  end

  ## Private Functions

  defp deliver_event(handler, event, opts) do
    # Check filter
    if passes_filter?(event, opts) do
      start_time = monotonic_time()

      result =
        try do
          Handler.call(handler, event)
        catch
          kind, error ->
            Logger.error("Handler crashed",
              kind: kind,
              error: inspect(error),
              handler: inspect(handler),
              event_type: event.type
            )

            {:error, {:handler_crashed, kind, error}}
        end

      elapsed = monotonic_time() - start_time

      result_status =
        case result do
          {status, _} -> status
          status when is_atom(status) -> status
        end

      emit_telemetry(:handler_complete, %{
        result: result_status,
        duration: elapsed
      })

      result
    else
      # Filter rejected the event
      {:ok, :filtered}
    end
  end

  defp passes_filter?(event, opts) do
    case Keyword.get(opts, :filter) do
      nil -> true
      filter when is_function(filter, 1) ->
        try do
          filter.(event)
        catch
          _, _ ->
            Logger.warning("Filter function crashed", handler: inspect(filter))
            false
        end
    end
  end

  defp emit_telemetry(event_name, measurements) do
    :telemetry.execute(
      [:web_ui, :dispatcher, event_name],
      measurements,
      %{}
    )
  rescue
    _ -> :telemetry_not_available
  end

  defp monotonic_time do
    System.monotonic_time(:millisecond)
  end
end
