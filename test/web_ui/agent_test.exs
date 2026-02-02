defmodule WebUi.AgentTest do
  use ExUnit.Case, async: true

  alias WebUi.Agent
  alias WebUi.CloudEvent
  alias WebUi.Dispatcher

  @moduletag :agent
  @moduletag :unit

  describe "use WebUi.Agent macro" do
    test "5.1.1 - use macro adds required callbacks" do
      defmodule TestAgentMacro do
        use WebUi.Agent

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}
      end

      # Verify the behaviour defines the required callback
      assert function_exported?(TestAgentMacro, :handle_cloud_event, 2)

      # Verify optional callbacks are defined
      assert function_exported?(TestAgentMacro, :init, 1)
      assert function_exported?(TestAgentMacro, :terminate, 2)
      assert function_exported?(TestAgentMacro, :child_spec, 1)
    end

    test "use macro with default implementations" do
      defmodule TestAgentDefaults do
        use WebUi.Agent

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}
      end

      # Test init returns default state
      assert {:ok, %{}} = TestAgentDefaults.init([])

      # Test terminate returns :ok
      assert :ok = TestAgentDefaults.terminate(:normal, %{})

      # Test child_spec returns valid spec
      spec = TestAgentDefaults.child_spec([])
      assert spec.id == TestAgentDefaults
      assert spec.restart == :permanent
    end
  end

  describe "handle_cloud_event/2" do
    test "5.1.2 - handle_cloud_event/2 is invoked" do
      defmodule TestAgentHandle do
        use GenServer
        use WebUi.Agent

        def subscribe_to, do: ["com.test.*"]

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

      # Start the agent
      {:ok, pid} = GenServer.start_link(TestAgentHandle, [])

      # Simulate dispatcher message
      event = CloudEvent.new!(source: "/test", type: "com.test.ping", data: %{})

      # Send the event as the dispatcher would
      GenServer.cast(pid, {:cloudevent, event})
      Process.sleep(10)

      # Check state was updated
      state = :sys.get_state(pid)
      assert length(state.events) == 1
      assert hd(state.events).type == "com.test.ping"

      # Cleanup
      GenServer.stop(pid)
    end

    test "handle_cloud_event returns {:reply, event, state}" do
      defmodule TestAgentReply do
        use WebUi.Agent

        @impl true
        def handle_cloud_event(%CloudEvent{type: "com.test.request"}, state) do
          response = CloudEvent.ok("response", %{result: "success"})
          {:reply, response, state}
        end
      end

      event = CloudEvent.new!(source: "/test", type: "com.test.request", data: %{})

      assert {:reply, reply_event, _state} = TestAgentReply.handle_cloud_event(event, %{})
      assert reply_event.type == "com.ok.response"
    end
  end

  describe "send_event/2" do
    setup do
      # Start dispatcher for testing
      start_supervised!(WebUi.Dispatcher)
      :ok
    end

    test "5.1.3 - send_event/2 emits to dispatcher" do
      # Create a test process to receive the event
      test_pid = self()

      # Subscribe to the event type we'll send
      {:ok, _ref} = Dispatcher.subscribe("com.test.send", fn event ->
        send(test_pid, {:received, event})
        :ok
      end)

      # Send an event
      :ok = Agent.send_event(nil, "com.test.send", %{message: "test"})

      # Verify the event was received
      assert_receive {:received, %CloudEvent{type: "com.test.send"}}
    end

    test "send_event with custom source" do
      test_pid = self()

      Dispatcher.subscribe("com.test.custom", fn event ->
        send(test_pid, {:received, event})
        :ok
      end)

      :ok = Agent.send_event(nil, "com.test.custom", %{}, source: "urn:custom:source")

      assert_receive {:received, %CloudEvent{source: "urn:custom:source"}}
    end

    test "send_event with correlation_id" do
      test_pid = self()

      Dispatcher.subscribe("com.test.corr", fn event ->
        send(test_pid, {:received, event})
        :ok
      end)

      :ok =
        Agent.send_event(
          nil,
          "com.test.corr",
          %{},
          correlation_id: "test-correlation-123"
        )

      assert_receive {:received,
                      %CloudEvent{
                        extensions: %{"correlationid" => "test-correlation-123"}
                      }}
    end
  end

  describe "reply/2" do
    test "5.1.4 - reply/2 sends response" do
      original_event =
        CloudEvent.new!(
          source: "/original",
          type: "com.example.request",
          data: %{action: "test"}
        )

      reply_event = Agent.reply(original_event, %{status: "processed"})

      # Verify reply event structure
      assert reply_event.type == "com.example.request.reply"
      assert reply_event.source =~ ~r/^urn:webui:agent:/
      assert reply_event.data == %{status: "processed"}
      assert reply_event.subject == original_event.id
    end

    test "reply preserves correlation ID" do
      original_event =
        CloudEvent.new!(
          source: "/original",
          type: "com.example.request",
          data: %{},
          extensions: %{"correlationid" => "original-correlation-456"}
        )

      reply_event = Agent.reply(original_event, %{result: "done"})

      # Verify correlation ID is preserved
      assert reply_event.extensions["correlationid"] == "original-correlation-456"
    end

    test "reply handles event without correlation ID" do
      original_event =
        CloudEvent.new!(
          source: "/original",
          type: "com.example.request",
          data: %{}
        )

      reply_event = Agent.reply(original_event, %{result: "done"})

      # No correlation ID in original, none in reply
      assert reply_event.extensions == nil or
             reply_event.extensions["correlationid"] == nil
    end
  end

  describe "subscription" do
    setup do
      start_supervised!(WebUi.Dispatcher)
      :ok
    end

    test "5.1.5 - agent subscribes to event types" do
      # Create a test agent process
      test_pid = self()

      # Subscribe to multiple patterns
      Agent.subscribe(test_pid, ["com.test.*", "com.other.*"])

      # Verify dispatcher has subscriptions
      all_subs = Dispatcher.subscriptions()
      test_patterns = all_subs
        |> Enum.filter(fn {_pattern, handler, _ref, _opts} ->
          handler == test_pid
        end)
        |> Enum.map(fn {pattern, _handler, _ref, _opts} -> pattern end)

      assert "com.test.*" in test_patterns
      assert "com.other.*" in test_patterns
    end

    test "subscribe with single pattern" do
      test_pid = self()

      Agent.subscribe(test_pid, "com.single.*")

      all_subs = Dispatcher.subscriptions()
      test_patterns = all_subs
        |> Enum.filter(fn {_pattern, handler, _ref, _opts} ->
          handler == test_pid
        end)
        |> Enum.map(fn {pattern, _handler, _ref, _opts} -> pattern end)

      assert ["com.single.*"] == test_patterns
    end
  end

  describe "optional callbacks" do
    test "5.1.6 - optional callbacks work" do
      test_pid = self()

      defmodule TestAgentCallbacks do
        use GenServer
        use WebUi.Agent

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def init(opts) do
          test_pid = Keyword.get(opts, :test_pid)
          custom_state = Keyword.get(opts, :custom_state, :default)
          {:ok, %{custom_state: custom_state, test_pid: test_pid}}
        end

        @impl true
        def terminate(reason, state) do
          send(state.test_pid, {:terminated, reason, state})
          :ok
        end

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
        @impl true
        def handle_info(_msg, state), do: {:noreply, state}
      end

      # Test custom init - pass options as init argument
      {:ok, pid} = GenServer.start_link(TestAgentCallbacks, [test_pid: test_pid, custom_state: :custom])
      state = :sys.get_state(pid)
      assert state.custom_state == :custom

      # Test terminate
      GenServer.stop(pid)
      assert_receive {:terminated, :normal, %{custom_state: :custom, test_pid: ^test_pid}}
    end
  end

  describe "correlation ID tracking" do
    test "5.1.7 - correlation IDs are tracked" do
      defmodule TestAgentCorrelation do
        use WebUi.Agent

        @impl true
        def handle_cloud_event(event, state) do
          # Extract correlation ID
          correlation_id =
            case event.extensions do
              %{"correlationid" => id} -> id
              _ -> nil
            end

          # Store it in state
          new_state = Map.put(state, :last_correlation_id, correlation_id)
          {:ok, new_state}
        end
      end

      event_with_cid =
        CloudEvent.new!(
          source: "/test",
          type: "com.test.event",
          data: %{},
          extensions: %{"correlationid" => "test-123"}
        )

      {:ok, state} = TestAgentCorrelation.handle_cloud_event(event_with_cid, %{})
      assert state.last_correlation_id == "test-123"

      # Test without correlation ID
      event_without_cid =
        CloudEvent.new!(source: "/test", type: "com.test.event", data: %{})

      {:ok, state} = TestAgentCorrelation.handle_cloud_event(event_without_cid, %{})
      assert state.last_correlation_id == nil
    end
  end

  describe "event filtering" do
    setup do
      start_supervised!(WebUi.Dispatcher)
      :ok
    end

    test "5.1.8 - event filtering works" do
      test_pid = self()

      # Subscribe with a filter function
      filter_fn = fn %CloudEvent{data: data} ->
        Map.get(data, :allowed, true)
      end

      {:ok, _ref} =
        Dispatcher.subscribe("com.filter.*", test_pid, filter: filter_fn)

      # Send an allowed event
      allowed_event = CloudEvent.new!(source: "/test", type: "com.filter.test", data: %{allowed: true})
      Dispatcher.dispatch(allowed_event)

      # Should receive the event (wrapped in GenServer.cast)
      assert_receive {:"$gen_cast", {:cloudevent, ^allowed_event}}

      # Send a blocked event
      blocked_event = CloudEvent.new!(source: "/test", type: "com.filter.test", data: %{allowed: false})
      Dispatcher.dispatch(blocked_event)

      # Should NOT receive the event
      refute_receive {:"$gen_cast", {:cloudevent, ^blocked_event}}, 100
    end
  end

  describe "source generation" do
    setup do
      start_supervised!(WebUi.Dispatcher)
      :ok
    end

    test "generates correct source URIs" do
      # Subscribe to test events
      test_pid = self()

      Dispatcher.subscribe("test.source.*", fn event ->
        send(test_pid, {:received, event})
        :ok
      end)

      # Test PID source
      pid = self()
      _source_pid = Agent.send_event(pid, "test.source.pid", %{})
      assert_receive {:received, %CloudEvent{source: source}}
      assert source =~ ~r/^urn:webui:agent:#PID</

      # Test atom source
      _source_atom = Agent.send_event(:my_agent, "test.source.atom", %{})
      assert_receive {:received, %CloudEvent{source: source_atom}}
      assert source_atom == "urn:webui:agent:my_agent"
    end
  end

  describe "child_spec customization" do
    test "child_spec returns default spec" do
      defmodule TestAgentChildSpec do
        use WebUi.Agent

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}
      end

      spec = TestAgentChildSpec.child_spec([])
      assert spec.id == TestAgentChildSpec
      assert spec.restart == :permanent
      assert spec.shutdown == 5000
      assert spec.type == :worker
    end

    test "child_spec can be customized" do
      defmodule TestAgentChildSpecCustom do
        use WebUi.Agent

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def child_spec(opts) do
          default = super(opts)
          %{default | restart: :transient, shutdown: 1000}
        end
      end

      spec = TestAgentChildSpecCustom.child_spec([])
      assert spec.restart == :transient
      assert spec.shutdown == 1000
    end
  end

  describe "lifecycle hooks" do
    test "before_handle_event can veto processing" do
      defmodule TestAgentBeforeHook do
        use WebUi.Agent

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def before_handle_event(%CloudEvent{data: %{veto: true}}, _state), do: {:halt, :vetoed}
        def before_handle_event(_event, _state), do: :cont
      end

      event = CloudEvent.new!(source: "/test", type: "com.test", data: %{veto: true})
      assert {:halt, :vetoed} = TestAgentBeforeHook.before_handle_event(event, %{})
    end

    test "after_handle_event is called after processing" do
      defmodule TestAgentAfterHook do
        use WebUi.Agent

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def after_handle_event(_event, _result, _state), do: :ok
      end

      event =
        CloudEvent.new!(
          source: "/test",
          type: "com.test",
          data: %{}
        )

      assert :ok = TestAgentAfterHook.after_handle_event(event, {:ok, %{}}, %{})
    end

    test "on_restart is called on restart" do
      defmodule TestAgentRestartHook do
        use WebUi.Agent

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def on_restart(_reason), do: :ok
      end

      assert :ok = TestAgentRestartHook.on_restart(:crash)
    end
  end
end
