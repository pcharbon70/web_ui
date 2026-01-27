defmodule WebUi.ApplicationTest do
  use ExUnit.Case, async: false

  @moduletag :application

  doctest WebUi.Application

  describe "start/2" do
    test "starts the supervision tree with Registry and DynamicSupervisor" do
      # Ensure application is started
      Application.ensure_all_started(:web_ui)

      # Verify we can retrieve the supervisor
      assert Process.whereis(WebUi.Supervisor) != nil

      # Verify registry is started (required child)
      assert Process.whereis(WebUi.Registry) != nil

      # Verify dynamic supervisor is started (required child)
      assert Process.whereis(WebUi.DynamicSupervisor) != nil
    end

    test "starts with configured children" do
      # Configure children for this test
      Application.put_env(:web_ui, :start, children: [])

      # Restart application
      Application.stop(:web_ui)
      :timer.sleep(100)

      # Ensure all dependencies are started before restarting web_ui
      # When web_ui stops, it also stops Phoenix which is a dependency
      Application.ensure_all_started(:telemetry)
      Application.ensure_all_started(:phoenix)
      Application.ensure_all_started(:phoenix_html)
      Application.ensure_all_started(:phoenix_live_view)
      Application.ensure_all_started(:phoenix_pubsub)
      Application.ensure_all_started(:jason)
      Application.ensure_all_started(:decimal)

      # Application.start/2 returns :ok (not {:ok, pid}) when starting an app
      assert :ok = Application.start(:web_ui)

      # Verify supervisor started
      assert Process.whereis(WebUi.Supervisor) != nil

      # Verify Registry and DynamicSupervisor are always started
      assert Process.whereis(WebUi.Registry) != nil
      assert Process.whereis(WebUi.DynamicSupervisor) != nil
    end
  end

  describe "stop/1" do
    test "stops cleanly" do
      # Ensure application is started
      Application.ensure_all_started(:web_ui)

      # Stop should succeed
      assert :ok = Application.stop(:web_ui)

      # Verify processes are stopped
      refute Process.whereis(WebUi.Supervisor)

      # Restart for other tests
      Application.start(:web_ui)
    end
  end

  describe "children_to_start/0" do
    test "returns empty list when nothing is configured" do
      Application.delete_env(:web_ui, :start)
      Application.delete_env(:web_ui, :children)

      assert WebUi.Application.children_to_start() == []
    end

    test "returns configured children from :start keyword" do
      Application.put_env(:web_ui, :start, children: [:child1, :child2])

      assert WebUi.Application.children_to_start() == [:child1, :child2]

      # Cleanup
      Application.delete_env(:web_ui, :start)
    end

    test "returns configured children from :children key" do
      # Delete :start config to test the :children fallback
      Application.delete_env(:web_ui, :start)
      Application.put_env(:web_ui, :children, [:child3, :child4])

      assert WebUi.Application.children_to_start() == [:child3, :child4]

      # Cleanup
      Application.delete_env(:web_ui, :children)
    end
  end

  describe "default_children/0" do
    test "returns list of default children" do
      children = WebUi.Application.default_children()

      assert length(children) == 3

      # Verify Registry child
      registry_child =
        Enum.find(children, fn
          {Registry, opts} when is_list(opts) -> true
          {Registry, _, _} -> true
          _ -> false
        end)

      assert registry_child != nil

      # Verify DynamicSupervisor child
      ds_child =
        Enum.find(children, fn
          {DynamicSupervisor, opts} when is_list(opts) -> true
          {DynamicSupervisor, _, _} -> true
          _ -> false
        end)

      assert ds_child != nil

      # Verify Endpoint child
      endpoint_child =
        Enum.find(children, fn
          {WebUi.Endpoint, _} -> true
          _ -> false
        end)

      assert endpoint_child != nil
    end
  end

  describe "shutdown_timeout/0" do
    test "returns default timeout" do
      Application.delete_env(:web_ui, :shutdown_timeout)

      assert WebUi.Application.shutdown_timeout() == 30_000
    end

    test "returns configured timeout" do
      Application.put_env(:web_ui, :shutdown_timeout, 15_000)

      assert WebUi.Application.shutdown_timeout() == 15_000

      # Cleanup
      Application.delete_env(:web_ui, :shutdown_timeout)
    end
  end

  describe "supervision tree" do
    test "Registry is started and functional" do
      # Ensure application is started
      Application.ensure_all_started(:web_ui)

      assert Process.whereis(WebUi.Registry) != nil

      # Test that we can register a process
      # Registry.register returns {:ok, owner_pid} or {:error, reason}
      # The lookup returns [{registered_pid, associated_value}]
      test_pid = self()

      assert {:ok, _} = Registry.register(WebUi.Registry, "test_key", test_pid)

      # Verify lookup works - Registry.lookup returns [{pid, value}]
      # where pid is the process that registered and value is what we passed
      assert [{^test_pid, _}] = Registry.lookup(WebUi.Registry, "test_key")

      # Cleanup
      Registry.unregister(WebUi.Registry, "test_key")
    end

    test "DynamicSupervisor is started and functional" do
      # Ensure application is started
      Application.ensure_all_started(:web_ui)

      ds_pid = Process.whereis(WebUi.DynamicSupervisor)
      assert ds_pid != nil

      # Test that we can start a child
      child_spec = %{id: make_ref(), start: {Agent, :start_link, [fn -> :ok end]}}

      assert {:ok, _pid} = DynamicSupervisor.start_child(ds_pid, child_spec)
    end
  end
end
