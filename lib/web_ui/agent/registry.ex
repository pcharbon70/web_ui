defmodule WebUi.Agent.Registry do
  @moduledoc """
  Registry for tracking WebUI agents and their event subscriptions.

  The AgentRegistry maintains a mapping of event types to agent PIDs,
  enabling efficient lookup of agents that should receive specific events.

  ## Features

  * Track agents by event type subscriptions
  * Support multiple agents per event type
  * Automatic cleanup on agent death
  * Agent discovery and introspection
  * Health monitoring
  * Size limits to prevent memory exhaustion

  ## Examples

      # Register an agent for specific event types
      :ok = WebUi.Agent.Registry.register(agent_pid, ["com.example.*", "com.other.*"])

      # Lookup agents for an event type
      agents = WebUi.Agent.Registry.lookup("com.example.event")
      # => [{agent_pid, ["com.example.*"]}]

      # Unregister an agent
      :ok = WebUi.Agent.Registry.unregister(agent_pid)

      # List all registered agents
      all = WebUi.Agent.Registry.list_agents()
      # => [%{pid: pid, subscriptions: [...], started_at: ...}]

  """

  use GenServer
  require Logger

  @max_subscriptions_per_agent 100
  @max_total_entries 10_000
  @default_timeout 5000

  @type agent_pid :: pid()
  @type event_pattern :: String.t()
  @type subscription :: {event_pattern(), reference()}
  @type agent_info :: %{
          pid: agent_pid(),
          subscriptions: [event_pattern()],
          started_at: DateTime.t(),
          ref: reference()
        }

  @registry_table :webui_agent_registry
  @metadata_table :webui_agent_metadata

  # Client API

  @doc """
  Starts the AgentRegistry.

  ## Options

  * `:name` - The name to register the GenServer (default: __MODULE__)
  * `:max_subscriptions_per_agent` - Maximum subscriptions per agent (default: 100)
  * `:max_total_entries` - Maximum total registry entries (default: 10_000)

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Registers an agent with its event subscriptions.

  The agent will be tracked for discovery and can be looked up by event type.

  ## Examples

      :ok = WebUi.Agent.Registry.register(agent_pid, ["com.example.*"])

  """
  @spec register(agent_pid(), [event_pattern()]) :: :ok | {:error, term()}
  def register(pid, patterns) when is_pid(pid) and is_list(patterns) do
    GenServer.call(__MODULE__, {:register, pid, patterns}, @default_timeout)
  end

  @doc """
  Unregisters an agent from the registry.

  ## Examples

      :ok = WebUi.Agent.Registry.unregister(agent_pid)

  """
  @spec unregister(agent_pid()) :: :ok
  def unregister(pid) when is_pid(pid) do
    GenServer.call(__MODULE__, {:unregister, pid}, @default_timeout)
  end

  @doc """
  Looks up agents that should receive an event of the given type.

  Returns a list of {pid, patterns} tuples where patterns match the event type.

  ## Examples

      agents = WebUi.Agent.Registry.lookup("com.example.event")
      # => [{pid, ["com.example.*"]}]

  """
  @spec lookup(String.t()) :: [{agent_pid(), [event_pattern()]}]
  def lookup(event_type) when is_binary(event_type) do
    GenServer.call(__MODULE__, {:lookup, event_type}, @default_timeout)
  end

  @doc """
  Returns information about a specific agent.

  ## Examples

      info = WebUi.Agent.Registry.agent_info(agent_pid)
      # => %{pid: pid, subscriptions: [...], started_at: ...}

  """
  @spec agent_info(agent_pid()) :: {:ok, agent_info()} | {:error, :not_found}
  def agent_info(pid) when is_pid(pid) do
    GenServer.call(__MODULE__, {:agent_info, pid}, @default_timeout)
  end

  @doc """
  Lists all registered agents with their metadata.

  ## Examples

      agents = WebUi.Agent.Registry.list_agents()
      # => [%{pid: pid, subscriptions: [...], started_at: ...}]

  """
  @spec list_agents() :: [agent_info()]
  def list_agents do
    GenServer.call(__MODULE__, :list_agents, @default_timeout)
  end

  @doc """
  Returns the count of registered agents.

  ## Examples

      count = WebUi.Agent.Registry.count()
      # => 5

  """
  @spec count() :: non_neg_integer()
  def count do
    GenServer.call(__MODULE__, :count, @default_timeout)
  end

  @doc """
  Checks if an agent is registered.

  ## Examples

      registered? = WebUi.Agent.Registry.registered?(agent_pid)
      # => true

  """
  @spec registered?(agent_pid()) :: boolean()
  def registered?(pid) when is_pid(pid) do
    GenServer.call(__MODULE__, {:registered?, pid}, @default_timeout)
  end

  @doc """
  Returns health status of all agents.

  ## Examples

      health = WebUi.Agent.Registry.health_check()
      # => %{total: 5, alive: 5, dead: 0}

  """
  @spec health_check() :: %{total: non_neg_integer(), alive: non_neg_integer(), dead: non_neg_integer()}
  def health_check do
    GenServer.call(__MODULE__, :health_check, @default_timeout)
  end

  @doc """
  Clears all registered agents (for testing).

  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(__MODULE__, :clear, @default_timeout)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    max_subscriptions = Keyword.get(opts, :max_subscriptions_per_agent, @max_subscriptions_per_agent)
    max_entries = Keyword.get(opts, :max_total_entries, @max_total_entries)

    # Create ETS tables for agent tracking
    registry_table =
      :ets.new(@registry_table, [
        :named_table,
        :set,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])

    metadata_table =
      :ets.new(@metadata_table, [
        :named_table,
        :set,
        :public,
        read_concurrency: true
      ])

    state = %{
      registry_table: registry_table,
      metadata_table: metadata_table,
      max_subscriptions_per_agent: max_subscriptions,
      max_total_entries: max_entries
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:register, pid, patterns}, _from, state) do
    # Check subscription limit
    if length(patterns) > state.max_subscriptions_per_agent do
      {:reply, {:error, :too_many_subscriptions}, state}
    else
      # Check total entry limit
      current_count = :ets.info(state.metadata_table, :size)

      if current_count >= state.max_total_entries do
        {:reply, {:error, :registry_full}, state}
      else
        # Create a monitor reference for the agent
        ref = Process.monitor(pid)

        # Store subscriptions indexed by pattern
        Enum.each(patterns, fn pattern ->
          key = {:pattern, pattern}

          current =
            case :ets.lookup(state.registry_table, key) do
              [{^key, agents}] -> agents
              [] -> []
            end

          updated = [{pid, ref} | current]
          :ets.insert(state.registry_table, {key, updated})
        end)

        # Store metadata for the agent
        metadata = %{
          pid: pid,
          subscriptions: patterns,
          started_at: DateTime.utc_now(),
          ref: ref
        }

        :ets.insert(state.metadata_table, {pid, metadata})

        Logger.debug("Registered agent", pid: inspect(pid), patterns: patterns)
        {:reply, :ok, state}
      end
    end
  end

  def handle_call({:unregister, pid}, _from, state) do
    # Remove from all pattern indices
    :ets.foldl(
      fn {{:pattern, pattern}, agents}, acc ->
        case Enum.find(agents, fn {agent_pid, _ref} -> agent_pid == pid end) do
          nil ->
            acc
          {_agent_pid, ref} ->
            # Flush the monitor message and demonitor
            Process.demonitor(ref, [:flush])
            # Update the list without this agent
            updated = Enum.reject(agents, fn {agent_pid, _} -> agent_pid == pid end)

            if updated == [] do
              :ets.delete(state.registry_table, {:pattern, pattern})
            else
              :ets.insert(state.registry_table, {{:pattern, pattern}, updated})
            end

            acc
        end
      end,
      :ok,
      state.registry_table
    )

    # Remove metadata
    :ets.delete(state.metadata_table, pid)

    Logger.debug("Unregistered agent", pid: inspect(pid))
    {:reply, :ok, state}
  end

  def handle_call({:lookup, event_type}, _from, state) do
    # Find all patterns that match this event type
    matching_agents =
      :ets.foldl(
        fn {{:pattern, pattern}, agents}, acc ->
          if matches_pattern?(event_type, pattern) do
            # Get subscriptions for each matching agent
            Enum.reduce(agents, acc, fn {pid, _ref}, inner_acc ->
              case :ets.lookup(state.metadata_table, pid) do
                [{^pid, metadata}] ->
                  patterns = Map.get(metadata, :subscriptions, [])
                  # Add if not already in list
                  if Enum.any?(inner_acc, fn {p, _} -> p == pid end) do
                    inner_acc
                  else
                    [{pid, patterns} | inner_acc]
                  end

                [] ->
                  inner_acc
              end
            end)
          else
            acc
          end
        end,
        [],
        state.registry_table
      )

    {:reply, Enum.reverse(matching_agents), state}
  end

  def handle_call({:agent_info, pid}, _from, state) do
    case :ets.lookup(state.metadata_table, pid) do
      [{^pid, metadata}] -> {:reply, {:ok, metadata}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:list_agents, _from, state) do
    agents =
      :ets.tab2list(state.metadata_table)
      |> Enum.map(fn {_pid, metadata} -> metadata end)

    {:reply, agents, state}
  end

  def handle_call(:count, _from, state) do
    count = :ets.info(state.metadata_table, :size)
    {:reply, count, state}
  end

  def handle_call({:registered?, pid}, _from, state) do
    case :ets.lookup(state.metadata_table, pid) do
      [{_pid, _metadata}] -> {:reply, true, state}
      [] -> {:reply, false, state}
    end
  end

  def handle_call(:health_check, _from, state) do
    all_agents = :ets.tab2list(state.metadata_table)

    {alive, dead} =
      Enum.reduce(all_agents, {0, 0}, fn
        {_pid, %{pid: pid}}, {a, d} ->
          if Process.alive?(pid), do: {a + 1, d}, else: {a, d + 1}
      end)

    total = length(all_agents)
    {:reply, %{total: total, alive: alive, dead: dead}, state}
  end

  def handle_call(:clear, _from, state) do
    # Demonitor all agents
    :ets.foldl(
      fn {_pid, %{ref: ref}}, acc ->
        Process.demonitor(ref, [:flush])
        acc
      end,
      :ok,
      state.metadata_table
    )

    # Clear both tables
    :ets.delete_all_objects(state.registry_table)
    :ets.delete_all_objects(state.metadata_table)

    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    # Agent died - clean up its registrations
    Logger.debug("Agent down",
      pid: inspect(pid),
      reason: inspect(reason)
    )

    # Remove from pattern indices
    :ets.foldl(
      fn {{:pattern, pattern}, agents}, acc ->
        case Enum.find(agents, fn {agent_pid, agent_ref} -> agent_pid == pid and agent_ref == ref end) do
          nil ->
            acc

          {_agent_pid, _ref} ->
            # Update the list without this agent
            updated = Enum.reject(agents, fn {agent_pid, _} -> agent_pid == pid end)

            if updated == [] do
              :ets.delete(state.registry_table, {:pattern, pattern})
            else
              :ets.insert(state.registry_table, {{:pattern, pattern}, updated})
            end

            acc
        end
      end,
      :ok,
      state.registry_table
    )

    # Remove metadata
    :ets.delete(state.metadata_table, pid)

    {:noreply, state}
  end

  # Private Helpers

  # Check if an event type matches a pattern
  # Supports: exact match, prefix wildcard (*), suffix wildcard
  defp matches_pattern?(event_type, pattern) do
    cond do
      # Exact match
      event_type == pattern ->
        true

      # Full wildcard
      pattern == "*" ->
        true

      # Prefix wildcard: "com.example.*"
      String.ends_with?(pattern, ".*") ->
        # Remove the ".*" suffix and check if event_type starts with the prefix
        prefix = String.slice(pattern, 0, String.length(pattern) - 2)
        String.starts_with?(event_type, prefix)

      # Suffix wildcard: "*.event"
      String.starts_with?(pattern, "*.") ->
        # Remove the "*." prefix and check if event_type ends with the suffix
        suffix = String.slice(pattern, 2, String.length(pattern) - 2)
        String.ends_with?(event_type, suffix)

      # No match
      true ->
        false
    end
  end
end
