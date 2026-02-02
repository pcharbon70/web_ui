defmodule WebUi.Agent.Supervisor do
  @moduledoc """
  Dynamic supervisor for WebUI agents.

  Manages the lifecycle of dynamically started agent processes,
  providing automatic restart on failure and integration with
  the AgentRegistry for subscription tracking.

  ## Features

  * Dynamic agent start/stop/restart
  * Automatic subscription registration
  * Health monitoring
  * Graceful shutdown

  ## Example

      {:ok, pid} = WebUi.Agent.Supervisor.start_agent(MyAgent, [],
        subscribe_to: ["com.example.*"]
      )

  """

  use DynamicSupervisor
  require Logger

  alias WebUi.Agent.Registry

  @type agent_module :: module()
  @type opts :: keyword()
  @type start_opts :: keyword()

  @doc """
  Starts the agent supervisor.

  ## Options

    * `:name` - The name to register the supervisor (default: __MODULE__)
    * `:registry` - Registry process name (default: WebUi.Agent.Registry)

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    # Extract name from opts, use __MODULE__ as default
    {name, _opts} = Keyword.pop(opts, :name, __MODULE__)
    # DynamicSupervisor.start_link/3: module, init_arg, start_opts
    # The init_arg is passed to our init/1 callback (we ignore it and use fixed strategy)
    DynamicSupervisor.start_link(__MODULE__, [], name: name)
  end

  @doc """
  Starts a new agent process.

  ## Options

    * `:name` - Process name for the agent
    * `:subscribe_to` - Event patterns to subscribe to
    * `:dispatcher` - Dispatcher process name (default: WebUi.Dispatcher)
    * `:auto_restart` - Enable automatic restart on subscription (default: true)
    * All other options passed to the agent's `start_link/1`

  ## Examples

      {:ok, pid} = WebUi.Agent.Supervisor.start_agent(MyAgent, [])

      {:ok, pid} = WebUi.Agent.Supervisor.start_agent(
        MyAgent,
        [],
        subscribe_to: ["com.example.*", "com.test.*"]
      )

      {:ok, pid} = WebUi.Agent.Supervisor.start_agent(
        MyAgent,
        name: :my_agent,
        subscribe_to: ["com.example.*"]
      )

  """
  @spec start_agent(agent_module(), start_opts()) :: DynamicSupervisor.on_start_child()

  # 3-arity version for merging option lists
  def start_agent(agent_module, start_opts, extra_opts)
      when is_list(start_opts) and is_list(extra_opts) do
    # Merge the two option lists
    all_opts = Keyword.merge(start_opts, extra_opts)
    start_agent(agent_module, all_opts)
  end

  # Main implementation (with default for opts)
  def start_agent(agent_module, opts \\ []) when is_list(opts) do
    name = Keyword.get(opts, :name)
    subscribe_to = Keyword.get(opts, :subscribe_to)
    dispatcher = Keyword.get(opts, :dispatcher, WebUi.Dispatcher)
    auto_restart = Keyword.get(opts, :auto_restart, true)

    # Build child spec
    child_spec = build_child_spec(agent_module, name, opts)

    # Start the agent
    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} = result ->
        # Register subscriptions
        register_subscriptions(pid, agent_module, subscribe_to, dispatcher, auto_restart)
        result

      {:ok, pid, info} ->
        # Register subscriptions
        register_subscriptions(pid, agent_module, subscribe_to, dispatcher, auto_restart)
        {:ok, pid, info}

      error ->
        error
    end
  end

  @doc """
  Stops an agent process.

  ## Examples

      :ok = WebUi.Agent.Supervisor.stop_agent(:my_agent)
      :ok = WebUi.Agent.Supervisor.stop_agent(pid)

  """
  @spec stop_agent(atom() | pid()) :: :ok | {:error, term()}
  def stop_agent(agent_id) when is_atom(agent_id) or is_pid(agent_id) do
    case find_child_pid(agent_id) do
      {:ok, pid} ->
        # Unregister from registry before stopping
        Registry.unregister(pid)
        DynamicSupervisor.terminate_child(__MODULE__, pid)

      {:error, :not_found} = error ->
        error

      error ->
        error
    end
  end

  @doc """
  Restarts an agent process.

  ## Examples

      {:ok, pid} = WebUi.Agent.Supervisor.restart_agent(:my_agent)

  """
  @spec restart_agent(atom() | pid()) :: {:ok, pid()} | {:error, term()}
  def restart_agent(agent_id) do
    case find_child_pid(agent_id) do
      {:ok, _pid} ->
        # Terminate and let DynamicSupervisor restart it
        # Note: This doesn't preserve state
        case stop_agent(agent_id) do
          :ok ->
            Process.sleep(100)
            # The agent should be restarted by the supervisor
            case find_child_pid(agent_id) do
              {:ok, pid} -> {:ok, pid}
              error -> error
            end

          error ->
            error
        end

      error ->
        error
    end
  end

  @doc """
  Returns information about an agent.

  ## Examples

      {:ok, info} = WebUi.Agent.Supervisor.agent_info(:my_agent)
      {:ok, info} = WebUi.Agent.Supervisor.agent_info(pid)

  """
  @spec agent_info(atom() | pid()) :: {:ok, map()} | {:error, :not_found}
  def agent_info(agent_id) do
    with {:ok, pid} <- find_child_pid(agent_id),
         {:ok, children} <- DynamicSupervisor.which_children(__MODULE__),
         {%{
           id: ^agent_id,
           type: :worker,
           restart: restart
         } = _child} <- Keyword.get(children, pid) do
      # Get additional info from registry
      registry_info =
        case Registry.agent_info(pid) do
          {:ok, reg_info} ->
            %{subscriptions: reg_info.subscriptions}

          {:error, _} ->
            %{}
        end

      info = %{
        pid: pid,
        id: agent_id,
        restart: restart,
        started_at: DateTime.utc_now()
      }
      |> Map.merge(registry_info)

      {:ok, info}
    else
      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Returns all running agents.

  ## Examples

      agents = WebUi.Agent.Supervisor.list_agents()

  """
  @spec list_agents() :: [map()]
  def list_agents do
    case DynamicSupervisor.which_children(__MODULE__) do
      children when is_list(children) ->
        Enum.map(children, fn
          {pid, %{id: id, type: :worker}} ->
            case Registry.agent_info(pid) do
              {:ok, info} ->
                Map.put(info, :pid, pid)
                |> Map.put(:id, id)

              {:error, _} ->
                %{
                  pid: pid,
                  id: id,
                  subscriptions: []
                }
            end

          _ ->
            nil
        end)
        |> Enum.filter(& &1)

      [] ->
        []
    end
  end

  @doc """
  Returns the count of running agents.

  ## Examples

      count = WebUi.Agent.Supervisor.count()

  """
  @spec count() :: non_neg_integer()
  def count do
    case DynamicSupervisor.count_children(__MODULE__) do
      count when is_integer(count) -> count
      _ -> 0
    end
  end

  @doc """
  Checks if an agent is currently running.

  ## Examples

      true = WebUi.Agent.Supervisor.agent_running?(:my_agent)
      true = WebUi.Agent.Supervisor.agent_running?(pid)
      false = WebUi.Agent.Supervisor.agent_running?(:nonexistent)

  """
  @spec agent_running?(atom() | pid()) :: boolean()
  def agent_running?(agent_id) when is_atom(agent_id) or is_pid(agent_id) do
    case find_child_pid(agent_id) do
      {:ok, pid} ->
        Process.alive?(pid)

      {:error, _} ->
        false
    end
  end

  @doc """
  Stops all running agents gracefully.

  ## Examples

      :ok = WebUi.Agent.Supervisor.stop_all_agents()

  """
  @spec stop_all_agents() :: :ok
  def stop_all_agents do
    children = DynamicSupervisor.which_children(__MODULE__)

    Enum.each(children, fn
      {pid, _child} ->
        # Unregister from registry
        Registry.unregister(pid)
        # Stop the agent
        DynamicSupervisor.terminate_child(__MODULE__, pid)
    end)

    :ok
  end

  @doc """
  Returns health statistics for the supervisor.

  ## Examples

      health = WebUi.Agent.Supervisor.health_check()
      # => %{total: 5, active: 5, restarting: 0, dead: 0}

  """
  @spec health_check() :: map()
  def health_check do
    children = DynamicSupervisor.which_children(__MODULE__)

    active = Enum.count(children, fn {pid, _child} ->
      Process.alive?(pid)
    end)

    restarting = Enum.count(children, fn {pid, _child} ->
      not Process.alive?(pid)
    end)

    %{
      total: length(children),
      active: active,
      restarting: restarting,
      dead: restarting
    }
  end

  @doc """
  Returns a list of agent PIDs matching the given event type.

  This is a convenience function that delegates to `Registry.lookup/1`.

  ## Examples

      pids = WebUi.Agent.Supervisor.agents_for_event("com.example.*")

  """
  @spec agents_for_event(String.t()) :: [pid()]
  def agents_for_event(event_type) do
    case Registry.lookup(event_type) do
      agents when is_list(agents) ->
        Enum.map(agents, fn {pid, _patterns} -> pid end)

      _ ->
        []
    end
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    # DynamicSupervisor requires an init/1 callback that calls DynamicSupervisor.init/1
    # The strategy can be configured via opts, but we use a default here
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp build_child_spec(agent_module, _name, opts) do
    {name, opts} = Keyword.pop(opts, :name)

    # Remove supervisor-only options before building child spec
    # These are used by start_agent but not valid for child_spec
    # Note: :name is passed to the agent for GenServer registration
    supervisor_opts = [:subscribe_to, :dispatcher, :auto_restart]
    agent_opts = Keyword.drop(opts, supervisor_opts)

    # If name is provided, add it to agent_opts so GenServer can register
    agent_opts = if name, do: Keyword.put(agent_opts, :name, name), else: agent_opts

    default = %{
      id: name || agent_module,
      start: {agent_module, :start_link, [agent_opts]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }

    Supervisor.child_spec(default, [])
  end

  defp register_subscriptions(pid, agent_module, subscribe_to, _dispatcher, true) do
    patterns = resolve_subscribe_to(agent_module, subscribe_to)

    if patterns != [] do
      Registry.register(pid, patterns)
    else
      :ok
    end
  end

  defp register_subscriptions(_pid, _agent_module, _subscribe_to, _dispatcher, false) do
    :ok
  end

  defp resolve_subscribe_to(agent_module, nil) do
    if function_exported?(agent_module, :subscribe_to, 0) do
      apply(agent_module, :subscribe_to, [])
    else
      []
    end
  end

  defp resolve_subscribe_to(_agent_module, patterns) when is_list(patterns), do: patterns
  defp resolve_subscribe_to(_agent_module, pattern) when is_binary(pattern), do: [pattern]

  defp find_child_pid(agent_id) when is_atom(agent_id) do
    children = DynamicSupervisor.which_children(__MODULE__)

    case Enum.find(children, fn
      {_pid, %{id: ^agent_id}} -> true
      _ -> false
    end) do
      {pid, _child} -> {:ok, pid}
      nil -> {:error, :not_found}
    end
  end

  defp find_child_pid(agent_id) when is_pid(agent_id) do
    children = DynamicSupervisor.which_children(__MODULE__)

    case Enum.find(children, fn
      {^agent_id, _child} -> true
      _ -> false
    end) do
      {_pid, _child} -> {:ok, agent_id}
      nil -> {:error, :not_found}
    end
  end
end
