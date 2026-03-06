defmodule WebUi.TestSupport.DispatcherIncrementAction do
  use Jido.Action,
    name: "dispatcher_increment",
    description: "Increment the dispatcher test counter",
    schema: []

  alias Jido.Agent.Directive.StateModification

  @impl true
  def run(_params, context) do
    current = Map.get(context.state, :count, 0)
    next_count = current + 1

    {:ok, %{count: next_count, operation: "increment"},
     [%StateModification{op: :set, path: [:count], value: next_count}]}
  end
end

defmodule WebUi.TestSupport.DispatcherCounterAgent do
  use Jido.Agent,
    name: "dispatcher_counter",
    description: "Jido Agent used by dispatcher tests",
    schema: [count: [type: :integer, default: 0]],
    actions: [WebUi.TestSupport.DispatcherIncrementAction]

  alias Jido.Signal

  @state_changed_type "com.webui.counter.state_changed"
  @source "urn:webui:test:dispatcher"

  @impl true
  def transform_result(%Signal{} = signal, result, _agent) when is_map(result) do
    count = Map.get(result, :count, Map.get(result, "count"))
    operation = Map.get(result, :operation, Map.get(result, "operation"))

    response =
      Signal.new!(%{
        type: @state_changed_type,
        source: @source,
        data: %{
          "count" => count,
          "operation" => operation,
          "correlation_id" => signal.id
        }
      })

    {:ok, response}
  end

  def transform_result(_signal, result, _agent), do: {:ok, result}
end

defmodule WebUi.ServerAgentDispatcherTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias Jido.Instruction
  alias Jido.Signal
  alias WebUi.ServerAgentDispatcher
  alias WebUi.ServerAgents.CounterState
  alias WebUi.TestSupport.DispatcherCounterAgent
  alias WebUi.TestSupport.DispatcherIncrementAction

  setup do
    old_config = Application.get_env(:web_ui, WebUi.ServerAgentDispatcher)

    on_exit(fn ->
      case old_config do
        nil -> Application.delete_env(:web_ui, WebUi.ServerAgentDispatcher)
        config -> Application.put_env(:web_ui, WebUi.ServerAgentDispatcher, config)
      end
    end)

    :ok
  end

  test "dispatches counter increment signal to legacy callback agent modules" do
    Application.put_env(:web_ui, WebUi.ServerAgentDispatcher,
      agents: [WebUi.ServerAgents.CounterAgent],
      jido_servers: []
    )

    reset_counter_state!()
    :ok = CounterState.ensure_started()
    {:ok, _count} = CounterState.apply_operation(:reset)

    signal =
      Signal.new!(%{
        id: "client-1",
        source: "urn:webui:test-client",
        type: "com.webui.counter.increment",
        data: %{}
      })

    assert {:ok, [response]} = ServerAgentDispatcher.dispatch(signal)

    assert %Signal{} = response
    assert response.type == "com.webui.counter.state_changed"
    assert response.data["count"] == 1
    assert response.data["operation"] == "increment"
    assert response.data["correlation_id"] == "client-1"
  end

  test "dispatches signal through configured jido agent servers" do
    ensure_registry_started!()

    agent_id = "dispatcher-jido-test-#{System.unique_integer([:positive, :monotonic])}"
    start_jido_counter_server!(agent_id)

    Application.put_env(:web_ui, WebUi.ServerAgentDispatcher,
      agents: [],
      jido_servers: [{agent_id, WebUi.Registry}]
    )

    signal =
      Signal.new!(%{
        id: "client-jido-1",
        source: "urn:webui:test-client",
        type: "com.webui.counter.increment",
        data: %{}
      })

    assert {:ok, [response]} = ServerAgentDispatcher.dispatch(signal)

    assert %Signal{} = response
    assert response.type == "com.webui.counter.state_changed"
    assert response.data["count"] == 1
    assert response.data["operation"] == "increment"
    assert response.data["correlation_id"] == "client-jido-1"
  end

  test "dispatches signal through configured jido routes" do
    ensure_registry_started!()

    agent_id = "dispatcher-jido-route-#{System.unique_integer([:positive, :monotonic])}"
    start_jido_counter_server!(agent_id)

    Application.put_env(:web_ui, WebUi.ServerAgentDispatcher,
      agents: [],
      jido_servers: [],
      jido_routes: %{"com.webui.counter.increment" => [server: {agent_id, WebUi.Registry}]}
    )

    signal =
      Signal.new!(%{
        id: "client-jido-route-1",
        source: "urn:webui:test-client",
        type: "com.webui.counter.increment",
        data: %{}
      })

    assert {:ok, [response]} = ServerAgentDispatcher.dispatch(signal)

    assert response.type == "com.webui.counter.state_changed"
    assert response.data["count"] == 1
    assert response.data["operation"] == "increment"
    assert response.data["correlation_id"] == "client-jido-route-1"
  end

  test "supports wildcard route patterns for jido routes" do
    ensure_registry_started!()

    agent_id = "dispatcher-jido-wildcard-#{System.unique_integer([:positive, :monotonic])}"
    start_jido_counter_server!(agent_id)

    Application.put_env(:web_ui, WebUi.ServerAgentDispatcher,
      agents: [],
      jido_servers: [],
      jido_routes: [%{pattern: "com.webui.counter.*", server: {agent_id, WebUi.Registry}}]
    )

    signal =
      Signal.new!(%{
        id: "client-jido-wildcard-1",
        source: "urn:webui:test-client",
        type: "com.webui.counter.increment",
        data: %{}
      })

    assert {:ok, [response]} = ServerAgentDispatcher.dispatch(signal)
    assert response.type == "com.webui.counter.state_changed"
    assert response.data["count"] == 1
    assert response.data["operation"] == "increment"
  end

  test "route matches do not fall back to other targets when routed server is unhandled" do
    ensure_registry_started!()

    agent_id = "dispatcher-jido-priority-#{System.unique_integer([:positive, :monotonic])}"
    start_jido_counter_server!(agent_id, "com.webui.counter.decrement")

    Application.put_env(:web_ui, WebUi.ServerAgentDispatcher,
      agents: [WebUi.ServerAgents.CounterAgent],
      jido_servers: [],
      jido_routes: [{"com.webui.counter.increment", {agent_id, WebUi.Registry}}]
    )

    signal =
      Signal.new!(%{
        id: "client-jido-priority-1",
        source: "urn:webui:test-client",
        type: "com.webui.counter.increment",
        data: %{}
      })

    log =
      capture_log(fn ->
        assert :unhandled = ServerAgentDispatcher.dispatch(signal)
      end)

    assert log =~ "routing_error"
  end

  test "returns unhandled when jido agent server has no matching route" do
    ensure_registry_started!()

    agent_id = "dispatcher-jido-test-#{System.unique_integer([:positive, :monotonic])}"
    start_jido_counter_server!(agent_id)

    Application.put_env(:web_ui, WebUi.ServerAgentDispatcher,
      agents: [],
      jido_servers: [[server: {agent_id, WebUi.Registry}]]
    )

    signal =
      Signal.new!(%{
        id: "client-jido-2",
        source: "urn:webui:test-client",
        type: "com.webui.counter.unknown",
        data: %{}
      })

    log =
      capture_log(fn ->
        assert :unhandled = ServerAgentDispatcher.dispatch(signal)
      end)

    assert log =~ "routing_error"
  end

  test "returns unhandled when no target handles the signal type" do
    Application.put_env(:web_ui, WebUi.ServerAgentDispatcher,
      agents: [WebUi.ServerAgents.CounterAgent],
      jido_servers: []
    )

    signal =
      Signal.new!(%{
        id: "client-2",
        source: "urn:webui:test-client",
        type: "com.webui.unknown.event",
        data: %{}
      })

    assert :unhandled = ServerAgentDispatcher.dispatch(signal)
  end

  test "returns error for non-signal input" do
    assert {:error, :invalid_signal} = ServerAgentDispatcher.dispatch(%{})
  end

  defp ensure_registry_started! do
    case Process.whereis(WebUi.Registry) do
      nil ->
        start_supervised!({Registry, keys: :unique, name: WebUi.Registry})

      _pid ->
        :ok
    end
  end

  defp start_jido_counter_server!(agent_id, route_type \\ "com.webui.counter.increment") do
    start_supervised!(%{
      id: {:dispatcher_jido_server, agent_id},
      start:
        {DispatcherCounterAgent, :start_link,
         [
           [
             id: agent_id,
             registry: WebUi.Registry,
             routes: [
               {route_type, Instruction.new!(action: DispatcherIncrementAction)}
             ]
           ]
         ]}
    })
  end

  defp reset_counter_state! do
    case Process.whereis(CounterState) do
      nil ->
        :ok

      pid ->
        Process.unlink(pid)

        try do
          GenServer.stop(pid, :normal, 1_000)
        catch
          :exit, _ -> :ok
        end
    end
  end
end
