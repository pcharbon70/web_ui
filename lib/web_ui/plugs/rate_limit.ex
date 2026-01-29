defmodule WebUi.Plugs.RateLimit do
  @moduledoc """
  Rate limiting plug for HTTP requests.

  Uses ETS-based storage to track request rates per client identifier
  (typically IP address). Supports sliding window rate limiting with
  multiple limit tiers.

  ## Configuration

  Configure in your `config/config.exs`:

      config :web_ui, WebUi.Plugs.RateLimit,
        enabled: true,
        storage: WebUi.Plugs.RateLimit.ETSStorage,
        default_limits: [{100, 60_000}],  # 100 requests per 60 seconds
        cleanup_interval: 60_000

  ## Usage

  Add to your router pipeline:

      pipeline :api do
        plug(:accepts, ["json"])
        plug(WebUi.Plugs.RateLimit,
          name: :api,
          limits: [{100, 60_000}, {1000, 300_000}]
        )
      end

  ## Options

  * `:name` - Unique identifier for this rate limit (required)
  * `:limits` - List of `{max_requests, window_ms}` tuples (optional, uses default)
  * `:identifier` - Function to extract client identifier (optional, defaults to IP)
  * `:on_limit_exceeded` - Function to call when limit exceeded (optional)

  ## Response Headers

  When rate limiting is enabled, the following headers are added:

  * `X-RateLimit-Limit` - The request limit for the current window
  * `X-RateLimit-Remaining` - Remaining requests in current window
  * `X-RateLimit-Reset` - Unix timestamp when window resets

  ## Example

      # Custom rate limit for strict endpoints
      plug(WebUi.Plugs.RateLimit,
        name: :strict_api,
        limits: [{10, 60_000}]  # 10 requests per minute
      )

  """

  import Plug.Conn

  alias WebUi.Plugs.RateLimit.ETSStorage

  @type limit :: {pos_integer(), pos_integer()}
  @type options :: [
    name: atom(),
    limits: [limit()],
    identifier: (Plug.Conn.t() -> String.t()),
    on_limit_exceeded: (Plug.Conn.t() -> Plug.Conn.t())
  ]

  @doc """
  Initializes the rate limit plug with options.
  """
  @spec init(keyword()) :: keyword()
  def init(opts) do
    # Get app config for defaults
    app_config = Application.get_env(:web_ui, __MODULE__, [])
    enabled = Keyword.get(app_config, :enabled, true)

    if enabled do
      # Ensure storage is started
      _ = ensure_storage_started()

      # Merge defaults with options
      name = Keyword.fetch!(opts, :name)
      limits = Keyword.get(opts, :limits, Keyword.get(app_config, :default_limits, [{100, 60_000}]))

      [
        name: name,
        limits: validate_limits!(limits),
        identifier: Keyword.get(opts, :identifier, &default_identifier/1),
        on_limit_exceeded: Keyword.get(opts, :on_limit_exceeded, &default_on_limit_exceeded/1)
      ]
    else
      # Rate limiting disabled, return empty opts
      [enabled: false]
    end
  end

  @doc """
  Calls the rate limit plug, checking and enforcing rate limits.
  """
  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, opts) do
    if Keyword.get(opts, :enabled, true) do
      check_rate_limit(conn, opts)
    else
      conn
    end
  end

  # Private functions

  defp check_rate_limit(conn, opts) do
    identifier = opts[:identifier].(conn)
    limits = opts[:limits]

    # Check all limits (this also records the request if within limits)
    case ETSStorage.check_limits(identifier, limits) do
      {:ok, state} ->
        # Within limits, add headers and continue
        conn
        |> add_rate_limit_headers(state)

      {:error, :rate_limit_exceeded, state} ->
        # Limit exceeded, handle it
        conn
        |> add_rate_limit_headers(state)
        |> opts[:on_limit_exceeded].()
    end
  end

  defp default_identifier(conn) do
    # Use IP address as default identifier
    case conn.remote_ip do
      {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
      {a, b, c, d, e, f, g, h} ->
        <<a::8, b::8, c::8, d::8, e::8, f::8, g::8, h::8>>
        |> :inet.ntoa()
        |> to_string()
      ip -> inspect(ip)
    end
  end

  defp default_on_limit_exceeded(conn) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(429, Jason.encode!(%{error: "Rate limit exceeded"}))
    |> halt()
  end

  defp add_rate_limit_headers(conn, state) do
    conn
    |> put_resp_header("x-ratelimit-limit", to_string(state.limit))
    |> put_resp_header("x-ratelimit-remaining", to_string(state.remaining))
    |> put_resp_header("x-ratelimit-reset", to_string(state.reset))
  end

  defp ensure_storage_started do
    case Process.whereis(ETSStorage) do
      nil ->
        # Try to start storage, will be started by supervisor if configured
        case ETSStorage.start_link([]) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          _ -> :ok
        end

      _pid ->
        :ok
    end
  end

  defp validate_limits!(limits) when is_list(limits) do
    Enum.each(limits, fn
      {max, window} when is_integer(max) and max > 0 and is_integer(window) and window > 0 ->
        :ok

      invalid ->
        raise ArgumentError, """
        invalid rate limit configuration: #{inspect(invalid)}

        Expected: {max_requests, window_ms}
        Example: {100, 60_000}  # 100 requests per 60 seconds
        """
    end)

    limits
  end

  @doc """
  Checks if a request from the given identifier would be allowed.

  Returns `:ok` if allowed, `{:error, :rate_limit_exceeded}` if not.

  ## Examples

      iex> WebUi.Plugs.RateLimit.allow_request?("127.0.0.1", [{10, 60_000}])
      :ok

      iex> WebUi.Plugs.RateLimit.allow_request?("127.0.0.1", [{0, 60_000}])
      {:error, :rate_limit_exceeded}

  """
  @spec allow_request?(String.t() | atom(), [limit()]) :: :ok | {:error, :rate_limit_exceeded}
  def allow_request?(identifier, limits) when is_list(limits) do
    case ETSStorage.check_limits(identifier, limits) do
      {:ok, _state} -> :ok
      {:error, :rate_limit_exceeded, _state} -> {:error, :rate_limit_exceeded}
    end
  end

  @doc """
  Gets the current state for a given identifier.

  ## Examples

      iex> WebUi.Plugs.RateLimit.get_state("127.0.0.1", [{100, 60_000}])
      %{limit: 100, remaining: 95, reset: 1706534400}

  """
  @spec get_state(String.t() | atom(), [limit()]) :: map()
  def get_state(identifier, limits) do
    case ETSStorage.check_limits(identifier, limits, dry_run: true) do
      {:ok, state} -> state
      {:error, _reason, state} -> state
    end
  end
end

defmodule WebUi.Plugs.RateLimit.ETSStorage do
  @moduledoc """
  ETS-based storage for rate limiting.

  Uses an ETS table to track request counts per identifier within
  time windows. Handles cleanup of expired entries.

  This module is a GenServer that manages the ETS table and periodic cleanup.
  """

  use GenServer
  require Logger

  @table_name :web_ui_rate_limit
  @cleanup_interval 60_000

  ## Client API

  @doc """
  Starts the ETS storage GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Checks if the identifier is within the given limits.

  Returns `{:ok, state}` if within limits, or `{:error, :rate_limit_exceeded, state}` if exceeded.

  When multiple limits are provided, the most restrictive limit (smallest remaining)
  is used for the returned state.
  """
  def check_limits(identifier, limits, opts \\ []) when is_list(limits) do
    now = System.monotonic_time(:millisecond)
    dry_run = Keyword.get(opts, :dry_run, false)

    # Get or create entry for identifier
    entry = get_or_create_entry(identifier, limits, now)

    # Determine if we will record this request (for calculating remaining correctly)
    will_record = !dry_run

    # Check each limit and find the most restrictive one
    {exceeded, most_restrictive_state} =
      Enum.reduce(limits, {false, nil}, fn {max_requests, window_ms}, {exceeded_acc, min_state} ->
        window_start = now - window_ms

        # Count requests in this window
        count = count_requests_in_window(entry.requests, window_start)

        # If we're about to record this request, account for it in remaining
        effective_count = if will_record, do: count + 1, else: count
        remaining = max(0, max_requests - effective_count)
        reset = calculate_reset(entry.requests, window_start, window_ms, now)

        limit_state = %{
          limit: max_requests,
          remaining: remaining,
          reset: reset,
          window: window_ms
        }

        # Track if any limit is exceeded
        # Use > (not >=) because effective_count includes the current request
        limit_exceeded = effective_count > max_requests

        # Find the most restrictive limit (smallest remaining)
        # If we don't have a state yet, or this one has fewer remaining, use it
        new_min_state =
          if min_state == nil or remaining < min_state.remaining do
            limit_state
          else
            min_state
          end

        # Combine exceeded status (if any limit was exceeded, overall is exceeded)
        new_exceeded = exceeded_acc or limit_exceeded

        {new_exceeded, new_min_state}
      end)

    # Record the request if not a dry run and within limits
    if !dry_run and !exceeded do
      record_request(identifier, limits)
    end

    if exceeded do
      {:error, :rate_limit_exceeded, most_restrictive_state}
    else
      {:ok, most_restrictive_state}
    end
  end

  @doc """
  Records a request for the given identifier.
  Appends the timestamp to the existing list of requests.
  """
  def record_request(identifier, limits) do
    # Ensure table exists
    ensure_table_exists()

    now = System.monotonic_time(:millisecond)
    key = {identifier, :requests}

    # Get existing timestamps or create empty list
    existing =
      case :ets.lookup(@table_name, key) do
        [] -> []
        [{^key, timestamps}] when is_list(timestamps) -> timestamps
        [{^key, _timestamp}] -> []  # Handle single timestamp (legacy)
      end

    # Calculate the oldest window to keep timestamps for
    max_window =
      limits
      |> Enum.map(fn {_max, window} -> window end)
      |> Enum.max(fn -> 60_000 end)

    window_start = now - max_window

    # Add new timestamp and filter out old ones
    updated =
      [now | existing]
      |> Enum.filter(&(&1 >= window_start))

    # Store updated list
    :ets.insert(@table_name, {key, updated})
    :ok
  end

  @doc """
  Cleans up expired entries for a specific identifier.
  """
  def cleanup_identifier(identifier) do
    # Check if table exists first
    if :ets.whereis(@table_name) == :undefined do
      :ok
    else
      # Find all keys for this identifier and delete old entries
      pattern = {{identifier, :_}, :_}
      :ets.select_delete(@table_name, [{pattern, [], [{:const, true}]}])
      :ok
    end
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    # Create ETS table
    table =
      :ets.new(@table_name, [
        :named_table,
        :set,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])

    # Start periodic cleanup
    cleanup_interval = Keyword.get(opts, :cleanup_interval, @cleanup_interval)
    {:ok, %{table: table, cleanup_interval: cleanup_interval}, {:continue, :schedule_cleanup}}
  end

  @impl true
  def handle_info(:schedule_cleanup, state) do
    # Schedule next cleanup
    Process.send_after(self(), :cleanup, state.cleanup_interval)
    {:noreply, state}
  end

  def handle_info(:cleanup, state) do
    # Perform cleanup
    cleanup(state.cleanup_interval)
    Process.send_after(self(), :schedule_cleanup, state.cleanup_interval)
    {:noreply, state}
  end

  @impl true
  def handle_continue(:schedule_cleanup, state) do
    Process.send_after(self(), :cleanup, state.cleanup_interval)
    {:noreply, state}
  end

  ## Private Functions

  defp get_or_create_entry(identifier, _limits, _now) do
    # Ensure table exists
    ensure_table_exists()

    key = {identifier, :requests}

    case :ets.lookup(@table_name, key) do
      [] ->
        # Create new entry
        :ets.insert(@table_name, {key, []})
        %{identifier: identifier, requests: []}

      [{^key, requests}] when is_list(requests) ->
        %{identifier: identifier, requests: requests}

      [{^key, _invalid}] ->
        # Handle invalid data format - reset to empty list
        :ets.insert(@table_name, {key, []})
        %{identifier: identifier, requests: []}
    end
  end

  defp ensure_table_exists do
    case :ets.whereis(@table_name) do
      :undefined ->
        # Table doesn't exist, create it
        try do
          :ets.new(@table_name, [
            :named_table,
            :set,
            :public,
            read_concurrency: true,
            write_concurrency: true
          ])
        rescue
          _ -> :ok  # Table might have been created by another process
        end

      _pid ->
        :ok  # Table exists
    end
  end

  defp count_requests_in_window(requests, window_start) do
    # Count requests within the window
    Enum.count(requests, fn timestamp ->
      is_integer(timestamp) && timestamp >= window_start
    end)
  end

  defp calculate_reset(requests, window_start, window_ms, now) do
    # Find when the oldest request in the window will expire
    case Enum.filter(requests, &(&1 >= window_start)) do
      [] ->
        # No requests in window, reset is now + window
        now + window_ms

      requests_in_window ->
        # Reset is when the oldest request expires
        oldest = Enum.min(requests_in_window)
        oldest + window_ms
    end
  end

  defp cleanup(max_age) do
    now = System.monotonic_time(:millisecond)
    cutoff = now - max_age

    # Remove all requests older than cutoff
    :ets.foldl(
      fn {{_identifier, :requests} = key, requests}, acc ->
        filtered = Enum.filter(requests, &(&1 >= cutoff))

        if filtered == [] do
          :ets.delete(@table_name, key)
        else
          :ets.insert(@table_name, {key, filtered})
        end

        acc
      end,
      nil,
      @table_name
    )
  end
end
