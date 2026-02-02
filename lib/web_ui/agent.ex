defmodule WebUi.Agent do
  @moduledoc """
  Behaviour and helpers for WebUI agents that process CloudEvents.

  This module defines a behaviour for creating agents that subscribe to
  and handle CloudEvents from the WebUI dispatcher. Agents can be
  implemented as GenServer or Agent processes.

  ## Behaviour Definition

  Required callbacks:

    * `handle_cloud_event/2` - Handle incoming CloudEvents

  Optional callbacks:

    * `init/1` - Initialize agent state
    * `terminate/2` - Cleanup on termination
    * `child_spec/1` - Customize child spec for supervision
    * `subscribe_to/0` - Define subscription patterns
    * `before_handle_event/2` - Lifecycle hook before event processing
    * `after_handle_event/3` - Lifecycle hook after event processing
    * `on_restart/1` - Lifecycle hook on agent restart

  ## Example GenServer Agent

      defmodule MyAgent do
        use WebUi.Agent
        use GenServer

        # Subscribe to specific event types on startup
        def subscribe_to, do: ["com.example.*"]

        @impl true
        def init(opts) do
          {:ok, %{}}
        end

        @impl true
        def handle_cloud_event(%WebUi.CloudEvent{} = event, state) do
          # Process the event
          {:ok, state}
        end

        @impl true
        def handle_cast({:cloudevent, event}, state) do
          case handle_cloud_event(event, state) do
            {:ok, new_state} -> {:noreply, new_state}
            {:reply, response, new_state} -> {:noreply, new_state}
          end
        end

        @impl true
        def handle_info(msg, state) do
          {:noreply, state}
        end
      end

  ## Subscription Patterns

  Agents subscribe to events using patterns:

    * Exact match: `"com.example.event"`
    * Prefix wildcard: `"com.example.*"`
    * Suffix wildcard: `"*.event"`
    * Full wildcard: `"*"`

  ## Sending Events

  Use `send_event/2` to emit CloudEvents from your agent:

      WebUi.Agent.send_event(self(), "com.example.response", %{data: "value"})

  ## Replying to Events

  Use `reply/2` to respond to the source of an event:

      WebUi.Agent.reply(event, %{status: "processed"})

  ## Lifecycle Hooks

  Agents can optionally define lifecycle hooks:

    * `before_handle_event/2` - Called before each event, can veto processing
    * `after_handle_event/3` - Called after each event, for side effects
    * `on_restart/1` - Called when agent is restarted

  ## Telemetry

  The following telemetry events are emitted:

    * `[:web_ui, :agent, :event_received]` - When an event is received
    * `[:web_ui, :agent, :event_processed]` - After processing
    * `[:web_ui, :agent, :event_sent]` - When sending an event
    * `[:web_ui, :agent, :error]` - On processing errors

  ## Correlation IDs

  For request/response tracking, events can include a `correlationid` extension:

      event = %WebUi.CloudEvent{
        ...,
        extensions: %{"correlationid" => "unique-id"}
      }

  The `reply/2` function preserves this correlation ID in responses.

  """

  alias WebUi.CloudEvent
  alias WebUi.Dispatcher

  @type event :: CloudEvent.t()
  @type state :: term()
  @type on_start :: keyword()
  @type opts :: keyword()
  @type result :: {:ok, state()} | {:reply, event(), state()}

  @doc """
  Defines the subscription patterns for this agent.

  Override this function to specify which event types the agent should
  subscribe to. Called during agent startup.

  ## Examples

      def subscribe_to, do: ["com.example.*"]
      def subscribe_to, do: ["com.user.created", "com.user.updated"]
      def subscribe_to, do: ["*"]  # Subscribe to all events

  """
  @callback subscribe_to() :: [String.t()]

  @doc """
  Handles an incoming CloudEvent.

  Required callback that processes events matching the agent's subscription
  patterns.

  ## Return Values

    * `{:ok, state}` - Event processed successfully, new state
    * `{:reply, response_event, state}` - Event processed, send response

  ## Examples

      @impl true
      def handle_cloud_event(%CloudEvent{type: "com.example.ping"} = event, state) do
        {:ok, state}
      end

      @impl true
      def handle_cloud_event(%CloudEvent{type: "com.example.request"} = event, state) do
        response = CloudEvent.ok("response", %{result: "success"})
        {:reply, response, state}
      end

  """
  @callback handle_cloud_event(event(), state()) ::
    {:ok, state()} | {:reply, event(), state()}

  @doc """
  Optional callback for initializing the agent.

  Similar to GenServer's `c:init/1` but with WebUi.Agent specific options.

  ## Options

    * `:dispatcher` - Dispatcher process name (default: `WebUi.Dispatcher`)
    * `:subscribe_to` - List of event patterns to subscribe to
    * `:filter` - Optional filter function for incoming events

  """
  @callback init(on_start()) :: {:ok, state()} | {:ok, state(), keyword()}

  @doc """
  Optional callback for cleaning up on agent termination.

  """
  @callback terminate(reason :: term(), state()) :: any()

  @doc """
  Optional callback for defining a custom child spec.

  """
  @callback child_spec(opts()) :: Supervisor.child_spec()

  @doc """
  Optional lifecycle hook called before handling each event.

  Return `:cont` to continue processing or `{:halt, reason}` to stop.

  """
  @callback before_handle_event(event(), state()) :: :cont | {:halt, term()}

  @doc """
  Optional lifecycle hook called after handling each event.

  """
  @callback after_handle_event(event(), result(), state()) :: :ok

  @doc """
  Optional lifecycle hook called when agent is restarted.

  """
  @callback on_restart(reason :: term()) :: :ok

  @optional_callbacks [
    init: 1,
    terminate: 2,
    child_spec: 1,
    subscribe_to: 0,
    before_handle_event: 2,
    after_handle_event: 3,
    on_restart: 1
  ]

  @doc false
  defmacro __using__(_opts \\ []) do
    quote do
      @behaviour WebUi.Agent

      # Default implementations
      @impl true
      def init(opts) do
        state = %{}
        {:ok, state}
      end

      @impl true
      def terminate(_reason, _state) do
        :ok
      end

      @impl true
      def child_spec(opts) do
        # Extract :name from opts as it's handled specially
        {name, opts_without_name} = Keyword.pop(opts, :name)

        default = %{
          id: name || __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          restart: :permanent,
          shutdown: 5000,
          type: :worker
        }

        # Pass opts without :name to Supervisor.child_spec
        Supervisor.child_spec(default, opts_without_name)
      end

      # Default subscribe_to - empty list (no subscriptions)
      def subscribe_to, do: []

      # Default lifecycle hooks
      def before_handle_event(_event, _state), do: :cont
      def after_handle_event(_event, _result, _state), do: :ok
      def on_restart(_reason), do: :ok

      # Default start_link for agents using GenServer
      # Can be overridden for custom initialization
      def start_link(opts \\ []) do
        {name, opts} = Keyword.pop(opts, :name)
        gen_opts = if name, do: [name: name], else: []
        GenServer.start_link(__MODULE__, opts, gen_opts)
      end

      defoverridable init: 1,
                     terminate: 2,
                     child_spec: 1,
                     subscribe_to: 0,
                     before_handle_event: 2,
                     after_handle_event: 3,
                     on_restart: 1,
                     start_link: 1
    end
  end

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts an agent with the given options and subscribes to events.

  This is a convenience function that starts the process and handles
  automatic subscription to configured event patterns.

  ## Options

    * `:name` - Process name
    * `:dispatcher` - Dispatcher process name (default: `WebUi.Dispatcher`)
    * `:subscribe_to` - Event patterns to subscribe to (default: from `c:subscribe_to/0`)
    * `:filter` - Optional filter function for incoming events

  ## Examples

      {:ok, pid} = WebUi.Agent.start_link(MyAgent, [])

      {:ok, pid} = WebUi.Agent.start_link(
        MyAgent,
        name: :my_agent,
        subscribe_to: ["com.example.*"]
      )

  """
  @spec start_link(module(), opts()) :: GenServer.on_start()
  def start_link(module, opts \\ []) when is_atom(module) do
    {gen_opts, agent_opts} = Keyword.split(opts, [:name])

    # Get subscription patterns
    subscribe_to = Keyword.get(agent_opts, :subscribe_to, nil)
    dispatcher = Keyword.get(agent_opts, :dispatcher, WebUi.Dispatcher)

    # Start the process (assumes GenServer or Agent)
    case apply(module, :start_link, [gen_opts]) do
      {:ok, pid} = result ->
        subscribe_if_needed(pid, module, subscribe_to, dispatcher)
        result

      {:ok, pid, _extra} = result ->
        subscribe_if_needed(pid, module, subscribe_to, dispatcher)
        result

      error ->
        error
    end
  end

  @doc """
  Starts an agent without a link (asynchronous).

  ## Examples

      {:ok, pid} = WebUi.Agent.start(MyAgent, [])

  """
  @spec start(module(), opts()) :: GenServer.on_start()
  def start(module, opts \\ []) when is_atom(module) do
    Task.start(fn -> start_link(module, opts) end)
  end

  @doc """
  Sends a CloudEvent through the dispatcher.

  ## Examples

      :ok = WebUi.Agent.send_event(self(), "com.example.response", %{result: "success"})

      :ok = WebUi.Agent.send_event(
        self(),
        "com.example.custom",
        %{data: "value"},
        source: "urn:webui:agent"
      )

  """
  @spec send_event(GenServer.server() | nil, String.t(), CloudEvent.data(), keyword()) ::
    :ok | {:error, term()}
  def send_event(sender_or_nil, type, data, opts \\ [])
  def send_event(nil, type, data, opts) do
    source = Keyword.get(opts, :source, "urn:webui:agent")
    do_send_event(type, data, source, opts)
  end

  def send_event(sender, type, data, opts) when is_pid(sender) or is_atom(sender) do
    source = Keyword.get(opts, :source, agent_source(sender))
    do_send_event(type, data, source, opts)
  end

  @doc """
  Sends a reply event in response to an incoming event.

  Preserves the correlation ID if present in the original event.
  The reply type is derived from the original type (e.g., "com.example.request"
  becomes "com.example.request.reply").

  ## Examples

      @impl true
      def handle_cloud_event(event, state) do
        {:reply, WebUi.Agent.reply(event, %{status: "processed"}), state}
      end

  """
  @spec reply(event(), CloudEvent.data()) :: event()
  def reply(%CloudEvent{} = event, data) do
    # Extract correlation ID if present
    correlation_id =
      case event.extensions do
        %{"correlationid" => id} -> id
        _ -> nil
      end

    # Build reply type
    reply_type = event.type <> ".reply"

    # Build source (swap the event source to this agent)
    source = agent_source(nil)

    # Build reply event
    reply_opts = [
      source: source,
      type: reply_type,
      data: data,
      subject: event.id  # Reference original event ID as subject
    ]

    reply_opts =
      if correlation_id do
        Keyword.put(reply_opts, :extensions, %{"correlationid" => correlation_id})
      else
        reply_opts
      end

    CloudEvent.new!(reply_opts)
  end

  @doc """
  Subscribes an agent process to event patterns.

  ## Examples

      :ok = WebUi.Agent.subscribe(pid, "com.example.*")
      :ok = WebUi.Agent.subscribe(pid, ["com.example.*", "com.other.*"])

  """
  @spec subscribe(GenServer.server(), String.t() | [String.t()]) :: :ok
  def subscribe(pid, patterns) when is_list(patterns) do
    Enum.each(patterns, fn pattern -> subscribe(pid, pattern) end)
    :ok
  end

  def subscribe(pid, pattern) when is_binary(pattern) do
    # Subscribe the PID to the dispatcher
    {:ok, _ref} = Dispatcher.subscribe(pattern, pid)
    :ok
  end

  @doc """
  Unsubscribes an agent from event patterns.

  Note: This requires the subscription reference, so agents should
  track their own subscriptions if they need to unsubscribe.

  """
  @spec unsubscribe(reference()) :: :ok
  def unsubscribe(ref) when is_reference(ref) do
    Dispatcher.unsubscribe(ref)
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp subscribe_if_needed(pid, module, subscribe_to, _dispatcher) do
    patterns = resolve_subscribe_to(module, subscribe_to)

    Enum.each(patterns, fn pattern ->
      Dispatcher.subscribe(pattern, pid)
    end)

    :ok
  end

  defp resolve_subscribe_to(module, nil) do
    if function_exported?(module, :subscribe_to, 0) do
      apply(module, :subscribe_to, [])
    else
      []
    end
  end

  defp resolve_subscribe_to(_module, patterns) when is_list(patterns), do: patterns
  defp resolve_subscribe_to(_module, pattern) when is_binary(pattern), do: [pattern]

  defp do_send_event(type, data, source, opts) do
    event_opts = [
      source: source,
      type: type,
      data: data,
      time: DateTime.utc_now()
    ]

    # Add optional fields
    event_opts =
      case Keyword.get(opts, :subject) do
        nil -> event_opts
        subject -> Keyword.put(event_opts, :subject, subject)
      end

    event_opts =
      case Keyword.get(opts, :correlation_id) do
        nil -> event_opts
        cid ->
          # For keyword list, we need to get existing extensions differently
          existing_exts = Keyword.get(event_opts, :extensions)
          extensions = Map.merge(existing_exts || %{}, %{"correlationid" => cid})
          Keyword.put(event_opts, :extensions, extensions)
      end

    event = CloudEvent.new!(event_opts)

    emit_telemetry(:event_sent, %{type: type, source: source})
    Dispatcher.dispatch(event)
  end

  defp agent_source(pid) when is_pid(pid) do
    "urn:webui:agent:#{inspect(pid)}"
  end

  defp agent_source(atom) when is_atom(atom) do
    "urn:webui:agent:#{atom}"
  end

  defp agent_source(nil) do
    "urn:webui:agent:anonymous"
  end

  defp emit_telemetry(event_name, measurements) do
    :telemetry.execute(
      [:web_ui, :agent, event_name],
      measurements,
      %{}
    )
  rescue
    _ -> :telemetry_not_available
  end
end
