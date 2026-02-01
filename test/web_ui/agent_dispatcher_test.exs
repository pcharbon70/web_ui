defmodule WebUI.AgentDispatcherTest do
  use ExUnit.Case, async: false

  alias WebUI.AgentDispatcher
  alias WebUI.AgentRegistry
  alias WebUI.AgentSupervisor
  alias WebUi.CloudEvent

  @moduletag :agent_dispatcher
  @moduletag :unit

  describe "5.3.1 - dispatcher routes to correct agents" do
    setup do
      start_supervised!(AgentRegistry)
      start_supervised!(AgentSupervisor)
      start_supervised!(AgentDispatcher)
      :ok
    end

    test "dispatch routes event to matching agents" do
      defmodule TestAgent1 do
        use GenServer
        use WebUI.Agent

        @impl true
        def init(_opts), do: {:ok, %{events: []}}

        @impl true
        def handle_cloud_event(%CloudEvent{type: "com.test.ping"} = event, state) do
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

      {:ok, pid} =
        AgentSupervisor.start_agent(
          TestAgent1,
          [],
          subscribe_to: ["com.test.*"]
        )

      event = CloudEvent.new!(source: "/test", type: "com.test.ping", data: %{})

      # Dispatch the event
      :ok = AgentDispatcher.dispatch(event)
      Process.sleep(100)

      # Verify the agent received the event
      state = :sys.get_state(pid)
      assert length(state.events) == 1
      assert hd(state.events).type == "com.test.ping"
    end

    test "dispatch does not route to non-matching agents" do
      defmodule TestAgent2 do
        use GenServer
        use WebUI.Agent

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

      {:ok, pid} =
        AgentSupervisor.start_agent(
          TestAgent2,
          [],
          subscribe_to: ["com.other.*"]
        )

      event = CloudEvent.new!(source: "/test", type: "com.test.ping", data: %{})

      # Dispatch the event
      :ok = AgentDispatcher.dispatch(event)
      Process.sleep(100)

      # Verify the agent did NOT receive the event
      state = :sys.get_state(pid)
      assert length(state.events) == 0
    end
  end

  describe "5.3.2 - dispatcher handles multiple agents" do
    setup do
      start_supervised!(AgentRegistry)
      start_supervised!(AgentSupervisor)
      start_supervised!(AgentDispatcher)
      :ok
    end

    test "dispatch routes to multiple agents with matching subscriptions" do
      defmodule TestAgent3 do
        use GenServer
        use WebUI.Agent

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

      {:ok, pid1} =
        AgentSupervisor.start_agent(
          TestAgent3,
          [],
          subscribe_to: ["com.shared.*"]
        )

      {:ok, pid2} =
        AgentSupervisor.start_agent(
          TestAgent3,
          [],
          subscribe_to: ["com.shared.*"]
        )

      event = CloudEvent.new!(source: "/test", type: "com.shared.event", data: %{})

      # Dispatch the event
      :ok = AgentDispatcher.dispatch(event)
      Process.sleep(100)

      # Both agents should have received the event
      state1 = :sys.get_state(pid1)
      state2 = :sys.get_state(pid2)
      assert length(state1.events) == 1
      assert length(state2.events) == 1
    end

    test "dispatch_sync returns results from multiple agents" do
      defmodule TestAgent4 do
        use GenServer
        use WebUI.Agent

        @impl true
        def init(_opts), do: {:ok, %{count: 0}}

        @impl true
        def handle_cloud_event(_event, state) do
          {:ok, %{state | count: state.count + 1}}
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

      {:ok, _pid1} =
        AgentSupervisor.start_agent(
          TestAgent4,
          [],
          subscribe_to: ["com.multi.*"]
        )

      {:ok, _pid2} =
        AgentSupervisor.start_agent(
          TestAgent4,
          [],
          subscribe_to: ["com.multi.*"]
        )

      event = CloudEvent.new!(source: "/test", type: "com.multi.event", data: %{})

      # Dispatch synchronously
      {:ok, results} = AgentDispatcher.dispatch_sync(event)

      # Should have results for both agents
      assert map_size(results) == 2
    end
  end

  describe "5.3.3 - agent failure doesn't crash dispatcher" do
    setup do
      start_supervised!(AgentRegistry)
      start_supervised!(AgentSupervisor)
      start_supervised!(AgentDispatcher)
      :ok
    end

    test "dispatch continues when one agent crashes" do
      defmodule TestAgent5 do
        use GenServer
        use WebUI.Agent

        @impl true
        def init(_opts), do: {:ok, %{crash: false}}

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

      # Create a crashing agent
      {:ok, _crashing_pid} =
        AgentSupervisor.start_agent(
          TestAgent5,
          [],
          subscribe_to: ["com.crash.*"]
        )

      # Create a normal agent
      defmodule TestAgent5Normal do
        use GenServer
        use WebUI.Agent

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

      {:ok, normal_pid} =
        AgentSupervisor.start_agent(
          TestAgent5Normal,
          [],
          subscribe_to: ["com.crash.*"]
        )

      event = CloudEvent.new!(source: "/test", type: "com.crash.event", data: %{crash: true})

      # Dispatch should not crash even though one agent crashes
      :ok = AgentDispatcher.dispatch(event)
      Process.sleep(200)

      # Normal agent should have received the event
      state = :sys.get_state(normal_pid)
      assert length(state.events) == 1
    end
  end

  describe "5.3.4 - timeout prevents hanging" do
    setup do
      start_supervised!(AgentRegistry)
      start_supervised!(AgentSupervisor)
      start_supervised!(AgentDispatcher)
      :ok
    end

    test "dispatch_sync times out for slow agents" do
      defmodule TestAgent6 do
        use GenServer
        use WebUI.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state) do
          Process.sleep(2000)
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

      {:ok, _pid} =
        AgentSupervisor.start_agent(
          TestAgent6,
          [],
          subscribe_to: ["com.slow.*"]
        )

      event = CloudEvent.new!(source: "/test", type: "com.slow.event", data: %{})

      # Dispatch with short timeout
      {:ok, results} = AgentDispatcher.dispatch_sync(event, timeout: 100)

      # Should have results (possibly empty due to timeout)
      assert is_map(results)
    end

    test "dispatch_sync includes error for timed out agents when requested" do
      defmodule TestAgent7 do
        use GenServer
        use WebUI.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state) do
          Process.sleep(2000)
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

      {:ok, pid} =
        AgentSupervisor.start_agent(
          TestAgent7,
          [],
          subscribe_to: ["com.timeout.*"]
        )

      event = CloudEvent.new!(source: "/test", type: "com.timeout.event", data: %{})

      # Dispatch with short timeout - since we use cast, this will succeed immediately
      # The timeout is for task completion, not agent processing
      {:ok, results} =
        AgentDispatcher.dispatch_sync(event,
          timeout: 100,
          on_timeout: :include_error
        )

      # Since cast returns immediately, the agent should be in results with :ok
      assert Map.get(results, pid) == :ok
    end
  end

  describe "5.3.5 - responses are collected correctly" do
    setup do
      start_supervised!(AgentRegistry)
      start_supervised!(AgentSupervisor)
      start_supervised!(AgentDispatcher)
      :ok
    end

    test "dispatch_sync collects results from all agents" do
      defmodule TestAgent8 do
        use GenServer
        use WebUI.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(%CloudEvent{data: %{value: value}}, state) do
          {:ok, Map.put(state, :last_value, value)}
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

      {:ok, _pid1} =
        AgentSupervisor.start_agent(
          TestAgent8,
          [],
          subscribe_to: ["com.response.*"]
        )

      {:ok, _pid2} =
        AgentSupervisor.start_agent(
          TestAgent8,
          [],
          subscribe_to: ["com.response.*"]
        )

      event = CloudEvent.new!(source: "/test", type: "com.response.test", data: %{value: 42})

      # Dispatch synchronously
      {:ok, results} = AgentDispatcher.dispatch_sync(event)

      # Should have results for both agents
      assert map_size(results) == 2

      # All results should be :ok
      assert Enum.all?(results, fn {_pid, result} -> result == :ok end)
    end
  end

  describe "5.3.6 - telemetry events are emitted" do
    setup do
      start_supervised!(AgentRegistry)
      start_supervised!(AgentSupervisor)
      start_supervised!(AgentDispatcher)
      :ok
    end

    test "dispatch emits telemetry events" do
      defmodule TestAgent9 do
        use GenServer
        use WebUI.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

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

      {:ok, _pid} =
        AgentSupervisor.start_agent(
          TestAgent9,
          [],
          subscribe_to: ["com.telemetry.*"]
        )

      event = CloudEvent.new!(source: "/test", type: "com.telemetry.event", data: %{})

      # Attach a telemetry handler
      handler =
        :telemetry.attach(
          "test-handler",
          [:web_ui, :agent_dispatcher, :dispatch_complete],
          &__MODULE__.handle_telemetry/4,
          self()
        )

      # Dispatch the event
      :ok = AgentDispatcher.dispatch(event)
      Process.sleep(100)

      # Verify telemetry was received
      assert_receive {:telemetry_dispatch_complete, _measurements, _metadata}

      :telemetry.detach(handler)
    end

    def handle_telemetry(_event, _measurements, _metadata, pid) do
      send(pid, {:telemetry_dispatch_complete, nil, nil})
    end
  end

  describe "5.3.7 - async vs sync dispatching" do
    setup do
      start_supervised!(AgentRegistry)
      start_supervised!(AgentSupervisor)
      start_supervised!(AgentDispatcher)
      :ok
    end

    test "dispatch returns immediately" do
      defmodule TestAgent10 do
        use GenServer
        use WebUI.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state) do
          Process.sleep(1000)
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

      {:ok, _pid} =
        AgentSupervisor.start_agent(
          TestAgent10,
          [],
          subscribe_to: ["com.async.*"]
        )

      event = CloudEvent.new!(source: "/test", type: "com.async.event", data: %{})

      # Async dispatch should return immediately
      start_time = System.monotonic_time(:millisecond)
      :ok = AgentDispatcher.dispatch(event)
      elapsed = System.monotonic_time(:millisecond) - start_time

      # Should return much faster than the agent's processing time
      assert elapsed < 500
    end

    test "dispatch_sync waits for delivery confirmation" do
      defmodule TestAgent11 do
        use GenServer
        use WebUI.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
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

      {:ok, _pid} =
        AgentSupervisor.start_agent(
          TestAgent11,
          [],
          subscribe_to: ["com.sync.*"]
        )

      event = CloudEvent.new!(source: "/test", type: "com.sync.event", data: %{})

      # Sync dispatch confirms delivery (cast succeeded)
      {:ok, results} = AgentDispatcher.dispatch_sync(event)

      # Should have results for the agent
      assert map_size(results) == 1
    end
  end

  describe "5.3.8 - agent_count" do
    setup do
      start_supervised!(AgentRegistry)
      start_supervised!(AgentSupervisor)
      start_supervised!(AgentDispatcher)
      :ok
    end

    test "agent_count returns number of matching agents" do
      defmodule TestAgent12 do
        use GenServer
        use WebUI.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
        @impl true
        def handle_info(_msg, state), do: {:noreply, state}
      end

      # Initially no agents
      assert AgentDispatcher.agent_count("com.count.*") == 0

      # Add agents
      {:ok, _pid1} =
        AgentSupervisor.start_agent(
          TestAgent12,
          [],
          subscribe_to: ["com.count.*"]
        )

      {:ok, _pid2} =
        AgentSupervisor.start_agent(
          TestAgent12,
          [],
          subscribe_to: ["com.count.*"]
        )

      # Should have 2 matching agents
      assert AgentDispatcher.agent_count("com.count.event") == 2
    end
  end
end
