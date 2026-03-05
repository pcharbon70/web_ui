defmodule CounterExample.EventContractTest do
  use ExUnit.Case, async: true

  alias CounterExample.EventContract

  test "defines supported command types and state_changed type" do
    assert Enum.sort(EventContract.command_types()) ==
             Enum.sort([
               "com.webui.counter.increment",
               "com.webui.counter.decrement",
               "com.webui.counter.reset",
               "com.webui.counter.sync"
             ])

    assert EventContract.state_changed_type() == "com.webui.counter.state_changed"

    assert Enum.sort(EventContract.operations()) ==
             Enum.sort([:increment, :decrement, :reset, :sync])
  end

  test "maps command types to operations and operations to command types" do
    assert {:ok, :increment} =
             EventContract.operation_from_command_type("com.webui.counter.increment")

    assert {:ok, :decrement} =
             EventContract.operation_from_command_type("com.webui.counter.decrement")

    assert {:ok, :reset} =
             EventContract.operation_from_command_type("com.webui.counter.reset")

    assert {:ok, :sync} = EventContract.operation_from_command_type("com.webui.counter.sync")

    assert {:ok, "com.webui.counter.increment"} =
             EventContract.command_type_for_operation(:increment)

    assert {:ok, "com.webui.counter.decrement"} =
             EventContract.command_type_for_operation(:decrement)

    assert {:ok, "com.webui.counter.reset"} =
             EventContract.command_type_for_operation(:reset)

    assert {:ok, "com.webui.counter.sync"} = EventContract.command_type_for_operation(:sync)
  end

  test "returns :error for unknown command types and operations" do
    assert EventContract.operation_from_command_type("com.webui.counter.unknown") == :error
    assert EventContract.command_type_for_operation(:unknown) == :error
  end

  test "defines source URIs and supported specversion" do
    assert EventContract.client_source() == "urn:webui:examples:counter:client"
    assert EventContract.server_source() == "urn:webui:examples:counter"
    assert EventContract.specversion() == "1.0"
    assert EventContract.supported_specversion?("1.0")
    refute EventContract.supported_specversion?("0.3")
    refute EventContract.supported_specversion?(nil)
  end

  test "defines required and optional payload fields" do
    assert Enum.sort(EventContract.command_event_required_fields()) ==
             Enum.sort(["specversion", "id", "source", "type"])

    assert Enum.sort(EventContract.command_event_optional_fields()) ==
             Enum.sort(["data", "time"])

    assert Enum.sort(EventContract.state_changed_required_data_fields()) ==
             Enum.sort(["count", "operation"])

    assert Enum.sort(EventContract.state_changed_optional_data_fields()) ==
             Enum.sort(["correlation_id"])
  end
end
