defmodule WebUI.AgentSupervisor do
  @moduledoc """
  Dynamic supervisor for WebUI agents.

  The AgentSupervisor manages the lifecycle of WebUI agents, providing
  dynamic start/stop capabilities, automatic restart on failure, and
  graceful shutdown.

  ## Features

  * Dynamic agent start/stop
  * Automatic restart with configurable strategies
  * Agent registration and discovery
  * Graceful shutdown support
  * Health monitoring

  ## Examples

      # Start an agent
      {:ok, pid} = WebUI.AgentSupervisor.start_agent(MyAgent, name: :my_agent)

      # Stop an agent
      :ok = WebUI.AgentSupervisor.stop_agent(:my_agent)

      # List all agents
      agents = WebUI.AgentSupervisor.list_agents()
      # => [%{pid: pid, name: :my_agent, module: MyAgent}]

      # Count running agents
      count = WebUI.AgentSupervisor.count()
      # => 3

  ## Supervisor Strategy

  Uses `:one_for_one` strategy by default, meaning if one agent crashes,
  only that agent is restarted. This provides isolation between agents.

  """

  use DynamicSupervisor
  require Logger

  alias WebUI.AgentRegistry

  @type agent_module :: module()
  @type agent_name :: atom() | nil
  @type agent_id :: pid() | atom()
  @type agent_spec :: Supervisor.child_spec() | {module(), term()} | module()

  # Client API

  @doc """
  Starts the agent supervisor.

  ## Options

  * `:name` - The name to register the supervisor (default: __MODULE__)
  * `:strategy` - Supervision strategy: `:one_for_one` or `:one_for_all` (default: `:one_for_one`)
  * `:max_restarts` - Maximum restarts in time window (default: 3)
  * `:max_seconds` - Time window for max_restarts (default: 5)

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Starts a new agent under the supervisor.

  The agent will be automatically restarted if it crashes.

  ## Options

  * `:name` - Optional name for the agent
  * `:subscribe_to` - Event patterns to subscribe to
  * All other options are passed to the agent's `start_link/1`

  ## Examples

      # Start an unnamed agent
      {:ok, pid} = WebUI.AgentSupervisor.start_agent(MyAgent, [])

      # Start a named agent
      {:ok, pid} = WebUI.AgentSupervisor.start_agent(
        MyAgent,
        [],
        name: :my_agent
      )

      # Start with subscriptions
      {:ok, pid} = WebUI.AgentSupervisor.start_agent(
        MyAgent,
        [],
        subscribe_to: ["com.example.*"]
      )

  """
  @spec start_agent(agent_spec(), keyword()) :: {:ok, pid()} | {:error, term()}
  def start_agent(agent_module, opts \\ []) do
    start_agent(agent_module, opts, [])
  end

  def start_agent(agent_module, init_opts, extra_opts) when is_list(init_opts) and is_list(extra_opts) do
    all_opts = Keyword.merge(init_opts, extra_opts)

    # Extract subscription patterns and name before building child spec
    subscribe_to = Keyword.get(all_opts, :subscribe_to)
    name = Keyword.get(all_opts, :name)

    # Remove :subscribe_to and :name from options passed to child spec
    # (:subscribe_to is for registry only, :name is handled separately)
    agent_opts = all_opts |> Keyword.delete(:subscribe_to) |> Keyword.delete(:name)

    # Build child spec
    child_spec = build_child_spec(agent_module, name, agent_opts)

    # Start the agent
    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        # Register with the agent registry if subscriptions provided
        if subscribe_to do
          patterns = if is_list(subscribe_to), do: subscribe_to, else: [subscribe_to]
          AgentRegistry.register(pid, patterns)
        end

        Logger.info("Started agent",
          module: inspect(agent_module),
          pid: inspect(pid),
          name: inspect(name)
        )

        {:ok, pid}

      {:ok, pid, _extra} ->
        # Same as above for processes that return extra info
        if subscribe_to do
          patterns = if is_list(subscribe_to), do: subscribe_to, else: [subscribe_to]
          AgentRegistry.register(pid, patterns)
        end

        Logger.info("Started agent",
          module: inspect(agent_module),
          pid: inspect(pid),
          name: inspect(name)
        )

        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.warning("Agent already started",
          module: inspect(agent_module),
          pid: inspect(pid)
        )

        {:error, {:already_started, pid}}

      {:error, reason} = error ->
        Logger.error("Failed to start agent",
          module: inspect(agent_module),
          reason: inspect(reason)
        )

        error
    end
  end

  @doc """
  Stops an agent by ID (PID or name).

  ## Examples

      :ok = WebUI.AgentSupervisor.stop_agent(pid)
      :ok = WebUI.AgentSupervisor.stop_agent(:my_agent)

  """
  @spec stop_agent(agent_id()) :: :ok | {:error, term()}
  def stop_agent(agent_id) do
    case find_agent_pid(agent_id) do
      {:ok, pid} ->
        # Unregister from registry first
        AgentRegistry.unregister(pid)

        # Stop the agent
        case DynamicSupervisor.terminate_child(__MODULE__, pid) do
          :ok ->
            Logger.info("Stopped agent", pid: inspect(pid))
            :ok

          {:error, reason} = error ->
            Logger.error("Failed to stop agent",
              pid: inspect(pid),
              reason: inspect(reason)
            )

            error
        end

      :error ->
        {:error, :not_found}
    end
  end

  @doc """
  Restarts an agent by ID.

  ## Examples

      :ok = WebUI.AgentSupervisor.restart_agent(:my_agent)

  """
  @spec restart_agent(agent_id()) :: :ok | {:error, term()}
  def restart_agent(agent_id) do
    case find_agent_pid(agent_id) do
      {:ok, _pid} ->
        # Stop and let supervisor restart it
        case stop_agent(agent_id) do
          :ok ->
            # Give it a moment to restart
            Process.sleep(100)
            :ok

          error ->
            error
        end

      :error ->
        {:error, :not_found}
    end
  end

  @doc """
  Returns information about an agent.

  ## Examples

      {:ok, info} = WebUI.AgentSupervisor.agent_info(:my_agent)
      # => %{pid: pid, module: MyAgent, name: :my_agent}

  """
  @spec agent_info(agent_id()) :: {:ok, map()} | {:error, :not_found}
  def agent_info(agent_id) do
    # First check if this is a child of the supervisor
    children = DynamicSupervisor.which_children(__MODULE__)

    child_info =
      case agent_id do
        pid when is_pid(pid) ->
          Enum.find(children, fn
            {_id, child_pid, _type, _modules} when child_pid == pid -> true
            _ -> false
          end)

        name when is_atom(name) ->
          Enum.find(children, fn
            {^name, _pid, _type, _modules} -> true
            _ -> false
          end)
      end

    case child_info do
      nil ->
        {:error, :not_found}

      {id, pid, _type, modules} ->
        # Get registry info if available
        registry_info =
          case AgentRegistry.agent_info(pid) do
            {:ok, metadata} -> metadata
            {:error, _reason} -> %{pid: pid}
          end

        info =
          registry_info
          |> Map.put(:supervisor_id, id)
          |> Map.put(:modules, modules)

        {:ok, info}
    end
  end

  @doc """
  Lists all running agents.

  Returns a list of maps with agent information.

  ## Examples

      agents = WebUI.AgentSupervisor.list_agents()
      # => [%{pid: pid, module: MyAgent, name: :my_agent}]

  """
  @spec list_agents() :: [map()]
  def list_agents do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn
      {id, pid, :worker, [module]} when is_pid(pid) ->
        %{
          id: id,
          pid: pid,
          module: module,
          type: :worker,
          alive: Process.alive?(pid)
        }

      {id, pid, :worker, modules} when is_list(modules) and is_pid(pid) ->
        %{
          id: id,
          pid: pid,
          module: List.first(modules),
          modules: modules,
          type: :worker,
          alive: Process.alive?(pid)
        }

      {id, pid, type, modules} when is_pid(pid) ->
        %{
          id: id,
          pid: pid,
          modules: modules,
          type: type,
          alive: Process.alive?(pid)
        }

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Returns the count of running agents.

  ## Examples

      count = WebUI.AgentSupervisor.count()
      # => 3

  """
  @spec count() :: non_neg_integer()
  def count do
    DynamicSupervisor.count_children(__MODULE__).specs
  end

  @doc """
  Checks if an agent is running.

  ## Examples

      running? = WebUI.AgentSupervisor.agent_running?(:my_agent)
      # => true

  """
  @spec agent_running?(agent_id()) :: boolean()
  def agent_running?(agent_id) do
    case find_agent_pid(agent_id) do
      {:ok, _pid} -> true
      :error -> false
    end
  end

  @doc """
  Performs a health check on all agents.

  Returns a map with health statistics.

  ## Examples

      health = WebUI.AgentSupervisor.health_check()
      # => %{total: 5, active: 5, dead: 0}

  """
  @spec health_check() :: %{total: non_neg_integer(), active: non_neg_integer(), dead: non_neg_integer()}
  def health_check do
    agents = list_agents()

    {active, dead} =
      Enum.reduce(agents, {0, 0}, fn agent, {a, d} ->
        if agent.alive, do: {a + 1, d}, else: {a, d + 1}
      end)

    %{
      total: length(agents),
      active: active,
      dead: dead
    }
  end

  @doc """
  Stops all agents gracefully.

  ## Examples

      :ok = WebUI.AgentSupervisor.stop_all_agents()

  """
  @spec stop_all_agents() :: :ok
  def stop_all_agents do
    agents = list_agents()

    Enum.each(agents, fn agent ->
      if agent.alive do
        stop_agent(agent.pid)
      end
    end)

    :ok
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    strategy = Keyword.get(opts, :strategy, :one_for_one)
    max_restarts = Keyword.get(opts, :max_restarts, 3)
    max_seconds = Keyword.get(opts, :max_seconds, 5)

    Logger.info("Starting AgentSupervisor",
      strategy: strategy,
      max_restarts: max_restarts,
      max_seconds: max_seconds
    )

    DynamicSupervisor.init(
      strategy: strategy,
      max_restarts: max_restarts,
      max_seconds: max_seconds
    )
  end

  # Private Helpers

  # Build a child spec for an agent module
  defp build_child_spec(module, name, opts) when is_atom(module) do
    # Include name in opts for modules that define their own child_spec
    agent_opts = if name, do: Keyword.put(opts, :name, name), else: opts

    if function_exported?(module, :child_spec, 1) do
      # Use the module's child_spec if available
      # Note: if the module defines child_spec, it should handle :name option
      module.child_spec(agent_opts)
    else
      # Build a default child spec
      default_child_spec(module, name, opts)
    end
  end

  defp build_child_spec(spec, _name, _opts) when is_tuple(spec) do
    # Already a child spec
    spec
  end

  # Default child spec for agents that don't define one
  defp default_child_spec(module, name, opts) do
    # The default start_link in WebUI.Agent expects :name in opts
    start_args = if name, do: [[name: name] ++ opts], else: [opts]

    %{
      id: name || module,
      start: {module, :start_link, start_args},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end

  # Find the PID of an agent by ID (name or PID)
  defp find_agent_pid(pid) when is_pid(pid), do: {:ok, pid}

  defp find_agent_pid(name) when is_atom(name) do
    case Process.whereis(name) do
      nil -> :error
      pid -> {:ok, pid}
    end
  end

  defp find_agent_pid(_other), do: :error
end
