defmodule CounterExample.CounterEventHandlerTest do
  use ExUnit.Case, async: false

  alias CounterExample.{CounterEventHandler, CounterServer}

  setup do
    ensure_counter_server()
    CounterServer.apply_operation(:reset)
    :ok
  end

  test "returns unhandled for unknown event types" do
    assert CounterEventHandler.handle_cloudevent(%{"type" => "com.example.unknown"}, nil) ==
             :unhandled
  end

  test "increment event returns state_changed with updated count" do
    incoming = %{
      "specversion" => "1.0",
      "id" => "client-1",
      "source" => "urn:webui:test",
      "type" => "com.webui.counter.increment",
      "data" => %{}
    }

    assert {:ok, response} = CounterEventHandler.handle_cloudevent(incoming, nil)
    assert response["type"] == "com.webui.counter.state_changed"
    assert response["source"] == "urn:webui:examples:counter"
    assert response["data"]["count"] == 1
    assert response["data"]["operation"] == "increment"
    assert response["data"]["correlation_id"] == "client-1"
  end

  test "sync emits current state without modifying count" do
    CounterServer.apply_operation(:increment)
    CounterServer.apply_operation(:increment)

    incoming = %{
      "specversion" => "1.0",
      "id" => "client-2",
      "source" => "urn:webui:test",
      "type" => "com.webui.counter.sync",
      "data" => %{}
    }

    assert {:ok, response} = CounterEventHandler.handle_cloudevent(incoming, nil)
    assert response["data"]["count"] == 2
    assert response["data"]["operation"] == "sync"
    assert CounterServer.current_count() == 2
  end

  defp ensure_counter_server do
    case Process.whereis(CounterServer) do
      nil -> start_supervised!(CounterServer)
      _pid -> :ok
    end
  end
end
