defmodule WebUi.Dispatcher.HandlerTest do
  @moduledoc """
  Tests for WebUi.Dispatcher.Handler.
  """

  use ExUnit.Case, async: true

  alias WebUi.{CloudEvent, Dispatcher.Handler}

  describe "alive?/1" do
    test "returns true for module/function tuple" do
      assert Handler.alive?({IO, :inspect})
    end

    test "returns true for function" do
      assert Handler.alive?(fn -> :ok end)
    end

    test "returns true for alive PID" do
      assert Handler.alive?(self())
    end

    test "returns false for dead PID" do
      # Create a process that dies immediately
      pid = spawn(fn -> :ok end)
      Process.sleep(10)
      refute Handler.alive?(pid)
    end

    test "returns false for invalid handler" do
      refute Handler.alive?(nil)
    end
  end

  describe "call/2" do
    setup do
      {:ok, event: test_event()}
    end

    test "calls module/function handler", %{event: event} do
      # IO.inspect returns the value, not :ok
      assert Handler.call({IO, :inspect}, event) == event
    end

    test "calls module/function with args handler" do
      assert Handler.call({Kernel, :is_atom, [:test]}, true)
    end

    test "calls function handler", %{event: event} do
      handler = fn %CloudEvent{id: id} -> {:ok, id} end
      assert Handler.call(handler, event) == {:ok, event.id}
    end

    test "sends cast to PID handler", %{event: event} do
      # This just verifies the call doesn't crash
      # Actual delivery requires a running GenServer
      assert Handler.call(self(), event) == :ok
    end

    test "handles function crash", %{event: event} do
      handler = fn _ -> raise "crash" end
      assert {:error, {:handler_error, _reason}} = Handler.call(handler, event)
    end
  end

  describe "handler_id/1" do
    test "returns tuple for module/function" do
      id = Handler.handler_id({IO, :inspect})
      assert id == {IO, :inspect}
    end

    test "returns tuple for module/function/args" do
      id = Handler.handler_id({Kernel, :is_atom, []})
      assert id == {Kernel, :is_atom}
    end

    test "returns PID for PID handler" do
      pid = self()
      assert Handler.handler_id(pid) == pid
    end

    test "returns function itself for function handler" do
      handler = fn -> :ok end
      id = Handler.handler_id(handler)
      # For function handlers, we use the function itself as the ID
      assert id == handler
    end
  end

  # Helper functions

  defp test_event do
    %CloudEvent{
      specversion: "1.0",
      id: "test-123",
      source: "/test",
      type: "com.test.event",
      data: %{}
    }
  end
end
