defmodule WebUi.Dispatcher.Handler do
  @moduledoc """
  Behaviour for event handlers that receive CloudEvents from the dispatcher.

  Event handlers can be:
  - GenServer processes that receive casts
  - Module/function pairs that are called directly
  - Anonymous functions

  ## Examples

  ### GenServer Handler

      defmodule MyEventHandler do
        use GenServer

        @impl true
        def init(opts), do: {:ok, opts}

        @impl true
        def handle_cast({:cloudevent, event}, state) do
          # Handle the CloudEvent
          {:noreply, state}
        end

        def handle_cloudevent(event), do: {:ok, event}

        # Also implements WebUi.Dispatcher.Handler behaviour
        @impl true
        def handle_event(event) do
          handle_cloudevent(event)
        end
      end

  ### Function Handler

      defmodule MyFunctionHandler do
        @impl true
        def handle_event(%WebUi.CloudEvent{type: "com.example.event"} = event) do
          # Handle the event
          :ok
        end

        @impl true
        def handle_event(_event) do
          :ok
        end
      end

  ### Anonymous Function Handler

      handler = fn event ->
        IO.inspect(event)
        :ok
      end

      WebUi.Dispatcher.subscribe("com.example.*", handler)

  ## Callbacks

  * `handle_event/1` - Called when a matching CloudEvent is received

  ## Return Values

  * `:ok` - Event handled successfully
  * `{:error, reason}` - Event handling failed
  * `:skip` - Skip further processing

  """

  @type event :: WebUi.CloudEvent.t()
  @type handler_id :: term()
  @type subscription :: {pattern :: String.t(), handler :: handler()}

  @type handler ::
    {module(), atom()} |
    function() |
    {module(), atom(), args :: [term()]} |
    pid()

  @doc """
  Called when a CloudEvent is received that matches the handler's subscription.

  ## Parameters

  * `event` - The CloudEvent to handle

  ## Returns

  * `:ok` - Event handled successfully
  * `{:error, reason}` - Event handling failed
  * `:skip` - Skip further processing

  ## Examples

      @impl true
      def handle_event(%WebUi.CloudEvent{type: "com.example.event"} = event) do
        Process.event(event)
        :ok
      end

  """
  @callback handle_event(event()) :: :ok | {:error, term()} | :skip

  @optional_callbacks [handle_event: 1]

  @doc """
  Determines if the handler is alive and can receive events.

  For GenServer handlers, this checks if the process is alive.
  For function handlers, this always returns true.

  ## Examples

      iex> WebUi.Dispatcher.Handler.alive?(self())
      true

      iex> WebUi.Dispatcher.Handler.alive?(nil)
      false

  """
  @spec alive?(handler()) :: boolean()
  def alive?({module, _fun}) when is_atom(module), do: true
  def alive?(fun) when is_function(fun), do: true
  def alive?(pid) when is_pid(pid), do: Process.alive?(pid)
  def alive?(_), do: false

  @doc """
  Calls the handler with the given event.

  Supports various handler types:
  - `{module, function}` - Calls `module.function(event)`
  - `{module, function, args}` - Calls `apply(module, function, [event | args])`
  - Function - Calls `function.(event)`
  - PID - Sends `GenServer.cast(pid, {:cloudevent, event})`

  ## Examples

      iex> WebUi.Dispatcher.Handler.call({IO, :inspect}, %WebUi.CloudEvent{id: "123"})
      %WebUi.CloudEvent{id: "123"}

  """
  @spec call(handler(), event()) :: :ok | {:error, term()} | :skip
  def call({module, fun}, event) when is_atom(module) and is_atom(fun) do
    apply(module, fun, [event])
  rescue
    e -> {:error, {:handler_error, e}}
  end

  def call({module, fun, args}, event) when is_atom(module) and is_atom(fun) and is_list(args) do
    apply(module, fun, [event | args])
  rescue
    e -> {:error, {:handler_error, e}}
  end

  def call(fun, event) when is_function(fun, 1) do
    fun.(event)
  rescue
    e -> {:error, {:handler_error, e}}
  end

  def call(pid, event) when is_pid(pid) do
    if Process.alive?(pid) do
      GenServer.cast(pid, {:cloudevent, event})
      :ok
    else
      {:error, :dead_handler}
    end
  end

  @doc """
  Returns a unique ID for the handler.

  Used for tracking and unsubscribing handlers.

  ## Examples

      iex> handler = fn event -> :ok end
      iex> WebUi.Dispatcher.Handler.handler_id(handler)
      # Returns a reference or unique identifier

  """
  @spec handler_id(handler()) :: handler_id()
  def handler_id({module, fun}), do: {module, fun}
  def handler_id({module, fun, _args}), do: {module, fun}
  def handler_id(pid) when is_pid(pid), do: pid
  def handler_id(fun) when is_function(fun), do: fun
end
