defmodule WebUi.Dispatcher.Registry do
  @moduledoc """
  Registry for tracking event handler subscriptions.

  Uses ETS for efficient pattern matching and lookups.
  Handlers can subscribe by:
  - Exact type match ("com.example.event")
  - Prefix wildcard ("com.example.*")
  - Suffix wildcard ("*.event")
  - Full wildcard ("*")

  ## Examples

      iex> {:ok, _pid} = WebUi.Dispatcher.Registry.start_link()
      iex> handler = fn event -> :ok end
      iex> WebUi.Dispatcher.Registry.subscribe("com.example.*", handler)
      {:ok, #Reference<...>}

  """

  use GenServer
  require Logger

  @table_name :web_ui_dispatcher_registry
  @pattern_table_name :web_ui_dispatcher_patterns

  ## Client API

  @doc """
  Starts the registry.

  ## Options

  * `:name` - The name to register the GenServer (default: __MODULE__)

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Subscribes a handler to events matching the given pattern.

  ## Parameters

  * `pattern` - Event type pattern (supports wildcards)
  * `handler` - Handler function, {module, function}, or PID
  * `opts` - Subscription options

  ## Options

  * `:filter` - Optional filter function
  * `:metadata` - Optional metadata to attach to subscription

  ## Returns

  * `{:ok, subscription_id}` - Successfully subscribed
  * `{:error, reason}` - Subscription failed

  ## Examples

      # Function handler
      {:ok, sub_id} = WebUi.Dispatcher.Registry.subscribe(
        "com.example.*",
        fn event -> :ok end
      )

      # Module/function handler
      {:ok, sub_id} = WebUi.Dispatcher.Registry.subscribe(
        "com.example.event",
        {MyHandler, :handle_event}
      )

      # With filter
      {:ok, sub_id} = WebUi.Dispatcher.Registry.subscribe(
        "com.example.*",
        handler,
        filter: fn event -> event.source != "/blocked" end
      )

  """
  @spec subscribe(String.t(), WebUi.Dispatcher.Handler.handler(), keyword()) ::
          {:ok, reference()} | {:error, term()}
  def subscribe(pattern, handler, opts \\ []) do
    GenServer.call(__MODULE__, {:subscribe, pattern, handler, opts})
  end

  @doc """
  Unsubscribes a handler using the subscription ID.

  ## Examples

      WebUi.Dispatcher.Registry.unsubscribe(subscription_id)

  """
  @spec unsubscribe(reference()) :: :ok
  def unsubscribe(subscription_id) do
    GenServer.call(__MODULE__, {:unsubscribe, subscription_id})
  end

  @doc """
  Finds all handlers that match the given event type.

  ## Examples

      handlers = WebUi.Dispatcher.Registry.find_handlers("com.example.event")

  """
  @spec find_handlers(String.t()) :: [{WebUi.Dispatcher.Handler.handler(), reference(), keyword()}]
  def find_handlers(event_type) do
    # Check for exact matches
    exact = :ets.lookup(@table_name, {:type, event_type})

    # Check for wildcard matches
    wildcards =
      @pattern_table_name
      |> :ets.tab2list()
      |> Enum.filter(fn {pattern, _regex, _handler, _sub_id, _opts} ->
        matches_pattern?(pattern, event_type)
      end)

    Enum.map(exact ++ wildcards, fn
      {{:type, _pattern}, handler, sub_id, opts} -> {handler, sub_id, opts}
      {_pattern, _regex, handler, sub_id, opts} -> {handler, sub_id, opts}
    end)
  end

  @doc """
  Returns all subscriptions for a given handler.

  ## Examples

      subs = WebUi.Dispatcher.Registry.subscriptions_for(handler)

  """
  @spec subscriptions_for(WebUi.Dispatcher.Handler.handler()) :: [{reference(), String.t(), keyword()}]
  def subscriptions_for(handler) do
    handler_id = WebUi.Dispatcher.Handler.handler_id(handler)

    @table_name
    |> :ets.tab2list()
    |> Enum.filter(fn
      {{:type, _pattern}, ^handler_id, _sub_id, _opts} -> true
      {{:pattern, _pattern}, _regex, ^handler_id, _sub_id, _opts} -> true
      _ -> false
    end)
    |> Enum.map(fn
      {{:type, pattern}, _handler, sub_id, opts} -> {sub_id, pattern, opts}
      {{:pattern, pattern}, _regex, _handler, sub_id, opts} -> {sub_id, pattern, opts}
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Returns the count of active subscriptions.

  ## Examples

      count = WebUi.Dispatcher.Registry.count()

  """
  @spec count() :: non_neg_integer()
  def count do
    :ets.info(@table_name, :size) + :ets.info(@pattern_table_name, :size)
  end

  @doc """
  Returns all subscriptions (for debugging/testing).

  ## Examples

      all = WebUi.Dispatcher.Registry.all()

  """
  @spec all() :: [{String.t(), WebUi.Dispatcher.Handler.handler(), reference(), keyword()}]
  def all do
    exact =
      @table_name
      |> :ets.tab2list()
      |> Enum.map(fn {{:type, pattern}, handler, sub_id, opts} ->
        {pattern, handler, sub_id, opts}
      end)

    wildcard =
      @pattern_table_name
      |> :ets.tab2list()
      |> Enum.map(fn {pattern, _regex, handler, sub_id, opts} ->
        {pattern, handler, sub_id, opts}
      end)

    exact ++ wildcard
  end

  @doc """
  Clears all subscriptions (for testing).

  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    # ETS table for exact type matches
    # Key: {:type, pattern}, Value: {handler_id, subscription_id, opts}
    :ets.new(@table_name, [:named_table, :bag, :public, read_concurrency: true])

    # ETS table for wildcard patterns
    # Key: {pattern, compiled_regex}, Value: {handler_id, subscription_id, opts}
    :ets.new(@pattern_table_name, [:named_table, :bag, :public, read_concurrency: true])

    {:ok, %{}}
  end

  @impl true
  def handle_call({:subscribe, pattern, handler, opts}, _from, state) do
    sub_id = make_ref()
    handler_id = WebUi.Dispatcher.Handler.handler_id(handler)
    filter = Keyword.get(opts, :filter)
    metadata = Keyword.get(opts, :metadata, [])
    opts = [filter: filter, metadata: metadata]

    if wildcard?(pattern) do
      # Compile regex for wildcard patterns
      case compile_pattern(pattern) do
        {:ok, regex} ->
          :ets.insert(@pattern_table_name, {pattern, regex, handler_id, sub_id, opts})
          {:reply, {:ok, sub_id}, state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      :ets.insert(@table_name, {{:type, pattern}, handler_id, sub_id, opts})
      {:reply, {:ok, sub_id}, state}
    end
  end

  def handle_call({:unsubscribe, sub_id}, _from, state) do
    # Remove from exact matches table
    :ets.select_delete(@table_name, [
      {{{:type, :_}, :_, sub_id, :_}, [], [true]}
    ])

    # Remove from wildcard table
    :ets.select_delete(@pattern_table_name, [
      {{:_, :_, :_, sub_id, :_}, [], [true]}
    ])

    {:reply, :ok, state}
  end

  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table_name)
    :ets.delete_all_objects(@pattern_table_name)
    {:reply, :ok, state}
  end

  ## Private Functions

  defp wildcard?("*"), do: true
  defp wildcard?(pattern), do: String.contains?(pattern, "*")

  defp compile_pattern("*"), do: {:ok, :".*"}
  defp compile_pattern(pattern) do
    # Convert wildcard pattern to regex
    # "com.example.*" -> "^com\\.example\\..*$"
    # "*.event" -> "^.*\\.event$"
    regex_str =
      pattern
      |> String.replace(".", "\\.")
      |> String.replace("*", ".*")
      |> then(fn p -> "^#{p}$" end)

    case Regex.compile(regex_str) do
      {:ok, regex} -> {:ok, regex}
      {:error, reason} -> {:error, {:invalid_pattern, reason}}
    end
  end

  defp matches_pattern?(pattern, _event_type) when pattern == "*", do: true
  defp matches_pattern?(pattern, event_type) do
    case compile_pattern(pattern) do
      {:ok, regex} -> Regex.match?(regex, event_type)
      _ -> false
    end
  end
end
