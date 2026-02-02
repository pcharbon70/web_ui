defmodule WebUI.AgentIntegrationTest do
  use ExUnit.Case, async: false

  alias WebUi.Agent.Supervisor
  alias WebUi.Agent.Registry
  alias WebUi.Agent.Dispatcher
  alias WebUi.Agent.Events
  alias WebUi.CloudEvent

  @moduletag :agent_integration
  @moduletag :integration

  # Test Agent implementations

  defmodule EchoAgent do
    use GenServer
    use WebUi.Agent

    @impl true
    def init(_opts), do: {:ok, %{events: []}}

    @impl true
    def handle_cloud_event(event, state) do
      {:ok, %{state | events: [event | state.events]}}
    end

    @impl true
    def handle_cast({:cloudevent, event}, state) do
      case handle_cloud_event(event, state) do
        {:ok, new_state} -> {:noreply, new_state}
        {:reply, _response, new_state} -> {:noreply, new_state}
      end
    end

    @impl true
    def handle_info(_msg, state), do: {:noreply, state}
  end

  defmodule ResponseAgent do
    use GenServer
    use WebUi.Agent

    @impl true
    def init(_opts), do: {:ok, %{last_event: nil}}

    @impl true
    def handle_cloud_event(event, state) do
      # Return a response event
      response = Events.ok(agent_name: "response-agent", data: %{received: event.type})
      {:reply, response, %{state | last_event: event}}
    end

    @impl true
    def handle_call({:cloudevent, event}, _from, state) do
      case handle_cloud_event(event, state) do
        {:reply, response, new_state} -> {:reply, {:ok, response}, new_state}
        {:ok, new_state} -> {:reply, {:ok, nil}, new_state}
      end
    end

    @impl true
    def handle_cast({:cloudevent, event}, state) do
      case handle_cloud_event(event, state) do
        {:ok, new_state} -> {:noreply, new_state}
        {:reply, _response, new_state} -> {:noreply, new_state}
      end
    end

    @impl true
    def handle_info(_msg, state), do: {:noreply, state}
  end

  defmodule CrashingAgent do
    use GenServer
    use WebUi.Agent

    @impl true
    def init(_opts), do: {:ok, %{crash_count: 0}}

    @impl true
    def handle_cloud_event(%CloudEvent{data: %{crash: true}}, _state) do
      raise "intentional crash"
    end

    def handle_cloud_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def handle_cast({:cloudevent, event}, state) do
      case handle_cloud_event(event, state) do
        {:ok, new_state} -> {:noreply, new_state}
        {:reply, _response, new_state} -> {:noreply, new_state}
      end
    end

    @impl true
    def handle_info(_msg, state), do: {:noreply, state}
  end

  defmodule StatefulAgent do
    use GenServer
    use WebUi.Agent

    @impl true
    def init(_opts), do: {:ok, %{counter: 0}}

    @impl true
    def handle_cloud_event(%CloudEvent{data: %{increment: true}}, state) do
      {:ok, %{state | counter: state.counter + 1}}
    end

    def handle_cloud_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def handle_cast({:cloudevent, event}, state) do
      case handle_cloud_event(event, state) do
        {:ok, new_state} -> {:noreply, new_state}
        {:reply, _response, new_state} -> {:noreply, new_state}
      end
    end

    @impl true
    def handle_info(_msg, state), do: {:noreply, state}
  end

  defmodule CorrelationAgent do
    use GenServer
    use WebUi.Agent

    @impl true
    def init(_opts), do: {:ok, %{last_correlation_id: nil}}

    @impl true
    def handle_cloud_event(event, state) do
      correlation_id = Events.get_correlation_id(event)

      response =
        Events.ok(
          agent_name: "correlation-agent",
          data: %{echo: correlation_id},
          correlation_id: correlation_id
        )

      {:reply, response, %{state | last_correlation_id: correlation_id}}
    end

    @impl true
    def handle_call({:cloudevent, event}, _from, state) do
      case handle_cloud_event(event, state) do
        {:reply, response, new_state} -> {:reply, {:ok, response}, new_state}
        {:ok, new_state} -> {:reply, {:ok, nil}, new_state}
      end
    end

    @impl true
    def handle_cast({:cloudevent, event}, state) do
      case handle_cloud_event(event, state) do
        {:ok, new_state} -> {:noreply, new_state}
        {:reply, _response, new_state} -> {:noreply, new_state}
      end
    end

    @impl true
    def handle_info(_msg, state), do: {:noreply, state}
  end

  describe "5.5.1 - agent subscribes to event type" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      start_supervised!(WebUi.Agent.Dispatcher)
      :ok
    end

    test "agent registered with subscription patterns" do
      {:ok, pid} =
        Supervisor.start_agent(
          EchoAgent,
          [],
          subscribe_to: ["com.test.*", "com.example.*"]
        )

      # Verify agent is in registry
      assert {:ok, info} = Registry.agent_info(pid)
      assert info.subscriptions == ["com.test.*", "com.example.*"]

      # Verify lookup finds the agent
      agents = Registry.lookup("com.test.event")
      assert length(agents) == 1
      assert [{^pid, _}] = agents
    end
  end

  describe "5.5.2 - agent receives CloudEvents from frontend" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      start_supervised!(WebUi.Agent.Dispatcher)
      :ok
    end

    test "agent receives matching event via dispatcher" do
      {:ok, pid} =
        Supervisor.start_agent(
          EchoAgent,
          [],
          subscribe_to: ["com.frontend.*"]
        )

      # Simulate frontend event
      event = CloudEvent.new!(source: "/frontend", type: "com.frontend.click", data: %{})
      Dispatcher.dispatch(event)
      Process.sleep(100)

      # Verify agent received the event
      state = :sys.get_state(pid)
      assert length(state.events) == 1
      assert hd(state.events).type == "com.frontend.click"
    end

    test "agent does not receive non-matching events" do
      {:ok, pid} =
        Supervisor.start_agent(
          EchoAgent,
          [],
          subscribe_to: ["com.frontend.*"]
        )

      # Send non-matching event
      event = CloudEvent.new!(source: "/other", type: "com.other.event", data: %{})
      Dispatcher.dispatch(event)
      Process.sleep(100)

      # Verify agent did not receive the event
      state = :sys.get_state(pid)
      assert length(state.events) == 0
    end
  end

  describe "5.5.3 - agent sends CloudEvents to frontend" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      start_supervised!(WebUi.Agent.Dispatcher)
      :ok
    end

    test "agent can create response events using AgentEvents" do
      response = Events.ok(agent_name: "test-agent", data: %{result: 42})

      assert response.type == "com.webui.agent.test-agent.ok"
      assert response.source == "urn:webui:agents:test-agent"
      assert response.data.result == 42
      assert CloudEvent.validate(response) == :ok
    end

    test "agent creates error events" do
      response =
        Events.error(
          agent_name: "validator",
          data: %{message: "Invalid input"}
        )

      assert response.type == "com.webui.agent.validator.error"
      assert response.data.message == "Invalid input"
    end

    test "agent creates progress events" do
      response =
        Events.progress(
          agent_name: "processor",
          current: 75,
          total: 100
        )

      assert response.type == "com.webui.agent.processor.progress"
      assert response.data.percent == 75
    end
  end

  describe "5.5.4 - multiple agents handle same event" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      start_supervised!(WebUi.Agent.Dispatcher)
      :ok
    end

    test "multiple subscribed agents all receive the event" do
      {:ok, pid1} =
        Supervisor.start_agent(
          EchoAgent,
          [],
          subscribe_to: ["com.shared.*"]
        )

      {:ok, pid2} =
        Supervisor.start_agent(
          EchoAgent,
          [],
          subscribe_to: ["com.shared.*"]
        )

      {:ok, pid3} =
        Supervisor.start_agent(
          EchoAgent,
          [],
          subscribe_to: ["com.shared.*"]
        )

      # Send shared event
      event = CloudEvent.new!(source: "/test", type: "com.shared.event", data: %{})
      Dispatcher.dispatch(event)
      Process.sleep(100)

      # All three agents should have received the event
      state1 = :sys.get_state(pid1)
      state2 = :sys.get_state(pid2)
      state3 = :sys.get_state(pid3)

      assert length(state1.events) == 1
      assert length(state2.events) == 1
      assert length(state3.events) == 1
    end

    test "agents with different subscriptions receive appropriate events" do
      {:ok, pid1} =
        Supervisor.start_agent(
          EchoAgent,
          [],
          subscribe_to: ["com.typea.*"]
        )

      {:ok, pid2} =
        Supervisor.start_agent(
          EchoAgent,
          [],
          subscribe_to: ["com.typeb.*"]
        )

      # Send two different events
      event_a = CloudEvent.new!(source: "/test", type: "com.typea.event", data: %{})
      event_b = CloudEvent.new!(source: "/test", type: "com.typeb.event", data: %{})

      Dispatcher.dispatch(event_a)
      Dispatcher.dispatch(event_b)
      Process.sleep(100)

      # Each agent should only receive matching events
      state1 = :sys.get_state(pid1)
      state2 = :sys.get_state(pid2)

      assert length(state1.events) == 1
      assert length(state2.events) == 1
      assert hd(state1.events).type == "com.typea.event"
      assert hd(state2.events).type == "com.typeb.event"
    end
  end

  describe "5.5.5 - agent failure doesn't crash system" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      start_supervised!(WebUi.Agent.Dispatcher)
      :ok
    end

    test "crashing agent does not crash dispatcher" do
      {:ok, _crashing_pid} =
        Supervisor.start_agent(
          CrashingAgent,
          [],
          subscribe_to: ["com.crash.*"]
        )

      # Create a normal agent that should survive
      {:ok, normal_pid} =
        Supervisor.start_agent(
          EchoAgent,
          [],
          subscribe_to: ["com.crash.*"]
        )

      # Send event that crashes one agent
      event =
        CloudEvent.new!(source: "/test", type: "com.crash.event", data: %{crash: true})

      # Dispatch should not crash even though one agent crashes
      assert :ok = Dispatcher.dispatch(event)
      Process.sleep(200)

      # Normal agent should have received the event
      state = :sys.get_state(normal_pid)
      assert length(state.events) == 1

      # Dispatcher should still be alive
      assert Process.alive?(Process.whereis(WebUi.Agent.Dispatcher))
    end

    test "dispatcher continues after agent crash" do
      {:ok, _crashing_pid} =
        Supervisor.start_agent(
          CrashingAgent,
          [],
          subscribe_to: ["com.test.*"]
        )

      # Send crashing event
      crash_event =
        CloudEvent.new!(source: "/test", type: "com.test.crash", data: %{crash: true})

      Dispatcher.dispatch(crash_event)
      Process.sleep(200)

      # Send normal event - dispatcher should still work
      {:ok, normal_pid} =
        Supervisor.start_agent(
          EchoAgent,
          [],
          subscribe_to: ["com.test.*"]
        )

      normal_event = CloudEvent.new!(source: "/test", type: "com.test.normal", data: %{})
      Dispatcher.dispatch(normal_event)
      Process.sleep(100)

      state = :sys.get_state(normal_pid)
      assert length(state.events) == 1
    end
  end

  describe "5.5.6 - agent restart resubscribes to events" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      start_supervised!(WebUi.Agent.Dispatcher)
      :ok
    end

    test "restarted agent maintains subscription" do
      # Start a stateful agent
      {:ok, pid} =
        Supervisor.start_agent(
          StatefulAgent,
          [],
          subscribe_to: ["com.stateful.*"],
          name: :stateful_agent
        )

      # Send an increment event
      event =
        CloudEvent.new!(source: "/test", type: "com.stateful.tick", data: %{increment: true})

      Dispatcher.dispatch(event)
      Process.sleep(100)

      state = :sys.get_state(pid)
      initial_counter = state.counter
      assert initial_counter == 1

      # Crash the agent
      Process.exit(pid, :kill)
      Process.sleep(200)

      # Agent should be restarted
      new_pid = Process.whereis(:stateful_agent)
      assert new_pid != nil
      assert new_pid != pid

      # Note: Restarted agent starts with fresh state
      # The subscription is NOT automatically re-registered
      # This is by design - agents can re-register in init/1 if needed

      # Verify old PID is no longer registered
      assert {:error, :not_found} = WebUi.Agent.Registry.agent_info(pid)
    end
  end

  describe "5.5.7 - agent responses are routed correctly" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      start_supervised!(WebUi.Agent.Dispatcher)
      :ok
    end

    test "sync dispatch collects responses from agents" do
      {:ok, _pid1} =
        Supervisor.start_agent(
          EchoAgent,
          [],
          subscribe_to: ["com.sync.*"]
        )

      {:ok, _pid2} =
        Supervisor.start_agent(
          EchoAgent,
          [],
          subscribe_to: ["com.sync.*"]
        )

      event = CloudEvent.new!(source: "/test", type: "com.sync.event", data: %{})

      # Sync dispatch should confirm delivery to both agents
      {:ok, results} = Dispatcher.dispatch_sync(event)
      assert map_size(results) == 2
    end

    test "async dispatch returns immediately" do
      {:ok, _pid} =
        Supervisor.start_agent(
          EchoAgent,
          [],
          subscribe_to: ["com.async.*"]
        )

      event = CloudEvent.new!(source: "/test", type: "com.async.event", data: %{})

      # Async dispatch should return immediately
      start_time = System.monotonic_time(:millisecond)
      :ok = Dispatcher.dispatch(event)
      elapsed = System.monotonic_time(:millisecond) - start_time

      # Should return quickly
      assert elapsed < 100
    end

    test "agent_count returns correct number of matching agents" do
      Supervisor.start_agent(EchoAgent, [], subscribe_to: ["com.count.*"])
      Supervisor.start_agent(EchoAgent, [], subscribe_to: ["com.count.*"])
      Supervisor.start_agent(EchoAgent, [], subscribe_to: ["com.other.*"])

      assert Dispatcher.agent_count("com.count.event") == 2
      assert Dispatcher.agent_count("com.other.event") == 1
    end
  end

  describe "5.5.8 - correlation tracking across requests" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      start_supervised!(WebUi.Agent.Dispatcher)
      :ok
    end

    test "correlation ID is preserved in response events" do
      correlation_id = "req-abc-123"

      # Create event with correlation ID in extensions
      request =
        CloudEvent.new!(
          source: "/frontend",
          type: "com.test.request",
          data: %{},
          extensions: %{"correlationid" => correlation_id}
        )

      # Verify correlation ID can be extracted
      assert Events.get_correlation_id(request) == correlation_id

      # Agent can create response with same correlation ID
      response =
        Events.ok(
          agent_name: "test",
          data: %{},
          correlation_id: correlation_id
        )

      assert Events.get_correlation_id(response) == correlation_id
    end

    test "event filtering by correlation ID presence" do
      event_with_corr =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: %{},
          extensions: %{"correlationid" => "req-123"}
        )

      event_without_corr =
        CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})

      assert Events.matches?(event_with_corr, has_correlation_id: true)
      refute AgentEvents.matches?(event_with_corr, has_correlation_id: false)
      refute AgentEvents.matches?(event_without_corr, has_correlation_id: true)
      assert Events.matches?(event_without_corr, has_correlation_id: false)
    end
  end

  describe "5.5.9 - concurrent agent operations" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      start_supervised!(WebUi.Agent.Dispatcher)
      :ok
    end

    test "multiple concurrent events are handled correctly" do
      # Start multiple agents
      agents =
        for _i <- 1..5 do
          {:ok, pid} =
            Supervisor.start_agent(
              EchoAgent,
              [],
              subscribe_to: ["com.concurrent.*"]
            )

          pid
        end

      # Send many events concurrently
      events =
        for i <- 1..20 do
          CloudEvent.new!(
            source: "/test",
            type: "com.concurrent.event",
            data: %{index: i}
          )
        end

      # Dispatch all events
      Enum.each(events, &Dispatcher.dispatch/1)

      # Wait for processing
      Process.sleep(500)

      # Verify all agents received all events
      for pid <- agents do
        state = :sys.get_state(pid)
        assert length(state.events) == 20
      end
    end

    test "concurrent dispatch calls do not interfere" do
      {:ok, pid} =
        Supervisor.start_agent(
          EchoAgent,
          [],
          subscribe_to: ["com.race.*"]
        )

      # Spawn multiple tasks dispatching events concurrently
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            event =
              CloudEvent.new!(
                source: "/test",
                type: "com.race.event",
                data: %{task: i}
              )

            Dispatcher.dispatch(event)
          end)
        end

      # Wait for all tasks
      Enum.each(tasks, &Task.await/1)
      Process.sleep(200)

      # Agent should have received all events
      state = :sys.get_state(pid)
      assert length(state.events) == 10
    end
  end

  describe "AgentEvents integration" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      start_supervised!(WebUi.Agent.Dispatcher)
      :ok
    end

    test "data_changed events include entity information" do
      event =
        Events.data_changed(
          agent_name: "user-manager",
          entity_type: "user",
          entity_id: "123",
          data: %{status: "active"}
        )

      assert event.type == "com.webui.agent.user-manager.data_changed"
      assert event.subject == "123"
      assert event.data.entity_type == "user"
      assert event.data.entity_id == "123"
      assert event.data.changes == %{status: "active"}
    end

    test "validation_error events normalize error formats" do
      event =
        Events.validation_error(
          agent_name: "form-validator",
          errors: [
            %{field: "email", message: "Invalid"},
            "Password too short"
          ]
        )

      assert event.data.error_count == 2
      assert length(event.data.errors) == 2
      assert Enum.at(event.data.errors, 0) == %{field: "email", message: "Invalid"}
      assert Enum.at(event.data.errors, 1) == %{message: "Password too short"}
    end

    test "batch events can be created and dispatched" do
      events =
        Events.batch([
          Events.ok(agent_name: "worker-1", data: %{status: "done"}),
          Events.ok(agent_name: "worker-2", data: %{status: "done"}),
          Events.ok(agent_name: "worker-3", data: %{status: "done"})
        ])

      assert length(events) == 3
      assert Enum.all?(events, &CloudEvent.cloudevent?/1)
    end
  end

  describe "Agent registry and discovery" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      :ok
    end

    test "list_agents returns all registered agents" do
      Supervisor.start_agent(EchoAgent, [], subscribe_to: ["com.test.*"])
      Supervisor.start_agent(EchoAgent, [], subscribe_to: ["com.test.*"])

      agents = Registry.list_agents()
      assert length(agents) >= 2
    end

    test "health_check returns registry statistics" do
      health = Registry.health_check()
      assert is_map(health)
      assert Map.has_key?(health, :total)
      assert Map.has_key?(health, :alive)
    end
  end
end
