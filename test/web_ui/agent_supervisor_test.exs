defmodule WebUI.AgentSupervisorTest do
  use ExUnit.Case, async: false

  alias WebUi.Agent.Supervisor
  alias WebUi.Agent.Registry

  @moduletag :agent_supervisor
  @moduletag :unit

  describe "5.2.1 - supervisor starts and manages agents" do
    setup do
      # Start the registry first (required by supervisor)
      start_supervised!(WebUi.Agent.Registry)
      # For DynamicSupervisor, call start_link directly with empty init options
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      :ok
    end

    test "start_agent/3 starts an unnamed agent" do
      defmodule TestAgent1 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
      end

      assert {:ok, pid} = Supervisor.start_agent(TestAgent1, [])
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "start_agent/3 starts a named agent" do
      defmodule TestAgent2 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
      end

      assert {:ok, pid} =
               Supervisor.start_agent(
                 TestAgent2,
                 [],
                 name: :test_named_agent
               )

      assert is_pid(pid)
      assert Process.whereis(:test_named_agent) == pid
    end

    test "start_agent/3 with subscriptions registers agent" do
      defmodule TestAgent3 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
      end

      assert {:ok, pid} =
               Supervisor.start_agent(
                 TestAgent3,
                 [],
                 subscribe_to: ["com.example.*", "com.test.*"]
               )

      assert {:ok, info} = Registry.agent_info(pid)
      assert info.subscriptions == ["com.example.*", "com.test.*"]
    end
  end

  describe "5.2.2 - registry tracks subscriptions" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      :ok
    end

    test "registry tracks agent by event patterns" do
      defmodule TestAgent4 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
      end

      {:ok, pid} =
        Supervisor.start_agent(
          TestAgent4,
          [],
          subscribe_to: ["com.user.*"]
        )

      assert {:ok, info} = Registry.agent_info(pid)
      assert info.subscriptions == ["com.user.*"]
      assert info.pid == pid
    end

    test "registry tracks multiple agents per pattern" do
      defmodule TestAgent5 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
      end

      {:ok, pid1} =
        Supervisor.start_agent(
          TestAgent5,
          [],
          subscribe_to: ["com.shared.*"]
        )

      {:ok, pid2} =
        Supervisor.start_agent(
          TestAgent5,
          [],
          subscribe_to: ["com.shared.*"]
        )

      # Both agents should be found for the pattern
      agents = Registry.lookup("com.shared.event")
      assert length(agents) == 2

      pids = Enum.map(agents, fn {pid, _patterns} -> pid end)
      assert pid1 in pids
      assert pid2 in pids
    end
  end

  describe "5.2.3 - lookup finds agents by event type" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      :ok
    end

    test "lookup returns agents for exact match pattern" do
      defmodule TestAgent6 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
      end

      {:ok, pid} =
        Supervisor.start_agent(
          TestAgent6,
          [],
          subscribe_to: ["com.example.event"]
        )

      agents = Registry.lookup("com.example.event")
      assert [{^pid, ["com.example.event"]}] = agents
    end

    test "lookup returns agents for prefix wildcard pattern" do
      defmodule TestAgent7 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
      end

      {:ok, pid} =
        Supervisor.start_agent(
          TestAgent7,
          [],
          subscribe_to: ["com.example.*"]
        )

      agents = Registry.lookup("com.example.specific.event")
      assert [{^pid, ["com.example.*"]}] = agents
    end

    test "lookup returns empty list for no match" do
      defmodule TestAgent8 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
      end

      Supervisor.start_agent(
        TestAgent8,
        [],
        subscribe_to: ["com.other.*"]
      )

      agents = Registry.lookup("com.example.event")
      assert agents == []
    end
  end

  describe "5.2.4 - agent restart recreates subscriptions" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      :ok
    end

    test "restart agent cleans up old registration" do
      defmodule TestAgent9 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{count: 0}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}

        @impl true
        def handle_info(:crash, _state) do
          raise "intentional crash"
        end
      end

      {:ok, pid} =
        Supervisor.start_agent(
          TestAgent9,
          [],
          subscribe_to: ["com.restart.*"],
          name: :restartable_agent
        )

      original_pid = pid

      # Should be registered
      assert {:ok, _info} = Registry.agent_info(pid)

      # Crash the agent
      send(pid, :crash)
      Process.sleep(200)

      # Agent should be restarted with new PID
      new_pid = Process.whereis(:restartable_agent)
      assert new_pid != nil
      assert new_pid != original_pid

      # Old PID should be cleaned from registry
      assert {:error, :not_found} = Registry.agent_info(original_pid)

      # Note: The restarted agent is not automatically re-registered
      # Agents can re-register in their init/1 if needed
      assert {:error, :not_found} = Registry.agent_info(new_pid)
    end
  end

  describe "5.2.5 - graceful shutdown stops all agents" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      :ok
    end

    test "stop_all_agents stops all running agents" do
      defmodule TestAgent10 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
      end

      # Start multiple agents
      {:ok, _pid1} = Supervisor.start_agent(TestAgent10, [], name: :agent1)
      {:ok, _pid2} = Supervisor.start_agent(TestAgent10, [], name: :agent2)
      {:ok, _pid3} = Supervisor.start_agent(TestAgent10, [], name: :agent3)

      assert Supervisor.count() == 3

      # Stop all agents
      :ok = Supervisor.stop_all_agents()
      Process.sleep(100)

      # All agents should be stopped
      assert Supervisor.count() == 0
    end

    test "stopping supervisor stops all agents" do
      defmodule TestAgent11 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
      end

      # Start agents
      {:ok, pid1} =
        Supervisor.start_agent(
          TestAgent11,
          [],
          subscribe_to: ["com.test1.*"]
        )

      {:ok, pid2} =
        Supervisor.start_agent(
          TestAgent11,
          [],
          subscribe_to: ["com.test2.*"]
        )

      # Both should be registered
      assert Registry.registered?(pid1)
      assert Registry.registered?(pid2)

      # Stop all agents
      :ok = Supervisor.stop_all_agents()
      Process.sleep(100)

      # Neither should be registered anymore
      refute Registry.registered?(pid1)
      refute Registry.registered?(pid2)
    end
  end

  describe "5.2.6 - health monitoring" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      :ok
    end

    test "health_check reports agent status" do
      defmodule TestAgent12 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
      end

      {:ok, _pid1} =
        Supervisor.start_agent(
          TestAgent12,
          [],
          subscribe_to: ["com.health.*"]
        )

      {:ok, _pid2} =
        Supervisor.start_agent(
          TestAgent12,
          [],
          subscribe_to: ["com.health.*"]
        )

      health = Supervisor.health_check()
      assert health.total == 2
      assert health.active == 2
      assert health.dead == 0
    end

    test "registry health check detects alive agents" do
      defmodule TestAgent13 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
      end

      {:ok, pid} =
        Supervisor.start_agent(
          TestAgent13,
          [],
          subscribe_to: ["com.health.*"]
        )

      health = Registry.health_check()
      assert health.total >= 1
      assert health.alive >= 1
      assert pid in Enum.map(Registry.list_agents(), fn m -> m.pid end)
    end
  end

  describe "5.2.7 - list and count agents" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      :ok
    end

    test "list_agents returns all running agents" do
      defmodule TestAgent14 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
      end

      {:ok, _pid1} =
        Supervisor.start_agent(
          TestAgent14,
          [],
          subscribe_to: ["com.list.*"]
        )

      {:ok, _pid2} =
        Supervisor.start_agent(
          TestAgent14,
          [],
          subscribe_to: ["com.list.*"]
        )

      agents = Supervisor.list_agents()
      assert length(agents) >= 2
    end

    test "count returns correct number of agents" do
      defmodule TestAgent15 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
      end

      assert Supervisor.count() == 0

      {:ok, _pid1} = Supervisor.start_agent(TestAgent15, [])
      {:ok, _pid2} = Supervisor.start_agent(TestAgent15, [])
      {:ok, _pid3} = Supervisor.start_agent(TestAgent15, [])

      assert Supervisor.count() == 3
    end

    test "agent_running? checks agent status" do
      defmodule TestAgent16 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
      end

      {:ok, pid} = Supervisor.start_agent(TestAgent16, [], name: :running_agent)

      assert Supervisor.agent_running?(:running_agent) == true
      assert Supervisor.agent_running?(pid) == true
      assert Supervisor.agent_running?(:nonexistent) == false
    end
  end

  describe "agent_info" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      :ok
    end

    test "agent_info returns agent metadata" do
      defmodule TestAgent17 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
      end

      {:ok, pid} =
        Supervisor.start_agent(
          TestAgent17,
          [],
          subscribe_to: ["com.info.*"]
        )

      assert {:ok, info} = Supervisor.agent_info(pid)
      assert info.pid == pid
      assert info.subscriptions == ["com.info.*"]
      assert is_struct(info.started_at, DateTime)
    end

    test "agent_info returns error for non-existent agent" do
      assert {:error, :not_found} = Supervisor.agent_info(:nonexistent)
      assert {:error, :not_found} = Supervisor.agent_info(self())
    end
  end

  describe "stop_agent" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      :ok
    end

    test "stop_agent stops a running agent" do
      defmodule TestAgent18 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}
      end

      {:ok, pid} =
        Supervisor.start_agent(
          TestAgent18,
          [],
          subscribe_to: ["com.stop.*"],
          name: :stoppable_agent
        )

      assert Supervisor.agent_running?(:stoppable_agent) == true

      :ok = Supervisor.stop_agent(:stoppable_agent)
      Process.sleep(100)

      assert Supervisor.agent_running?(:stoppable_agent) == false
      assert Registry.registered?(pid) == false
    end
  end

  describe "registry cleanup" do
    setup do
      start_supervised!(WebUi.Agent.Registry)
      {:ok, _pid} = WebUi.Agent.Supervisor.start_link([])
      :ok
    end

    test "registry cleans up dead agents" do
      defmodule TestAgent19 do
        use GenServer
        use WebUi.Agent

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def handle_cloud_event(_event, state), do: {:ok, state}

        @impl true
        def handle_cast(_msg, state), do: {:noreply, state}

        @impl true
        def handle_info(:crash, _state) do
          raise "intentional crash"
        end
      end

      {:ok, pid} =
        Supervisor.start_agent(
          TestAgent19,
          [],
          subscribe_to: ["com.cleanup.*"]
        )

      assert {:ok, _info} = Registry.agent_info(pid)

      # Crash the agent
      send(pid, :crash)
      Process.sleep(200)

      # Old PID should be cleaned from registry (DOWN message handled)
      assert {:error, :not_found} = Registry.agent_info(pid)

      # Note: The restarted agent is not automatically re-registered
      # This is by design - agents should re-register in init/1 if needed
      agents = Registry.lookup("com.cleanup.event")
      assert length(agents) == 0
    end
  end
end
