defmodule CounterExample.CounterEventHandlerTest do
  use ExUnit.Case, async: false

  alias CounterExample.{CounterEventHandler, CounterServer, EventContract}

  setup do
    ensure_counter_server()
    CounterServer.apply_operation(:reset)
    :ok
  end

  test "returns unhandled for unknown event types" do
    assert CounterEventHandler.handle_cloudevent(
             %{"specversion" => EventContract.specversion(), "type" => "com.example.unknown"},
             nil
           ) == :unhandled
  end

  test "returns unhandled for unsupported specversion" do
    incoming = incoming_command("com.webui.counter.increment", %{"specversion" => "0.3"})

    assert CounterEventHandler.handle_cloudevent(incoming, nil) == :unhandled
  end

  test "increment event returns state_changed with expected payload shape" do
    incoming = incoming_command("com.webui.counter.increment", %{"id" => "client-1"})

    assert {:ok, response} = CounterEventHandler.handle_cloudevent(incoming, nil)
    assert response["specversion"] == EventContract.specversion()
    assert response["type"] == EventContract.state_changed_type()
    assert response["source"] == EventContract.server_source()
    assert is_binary(response["id"])
    assert is_binary(response["time"])
    assert Map.has_key?(response, "data")
    assert response["data"]["count"] == 1
    assert response["data"]["operation"] == "increment"
    assert response["data"]["correlation_id"] == "client-1"

    assert MapSet.subset?(
             MapSet.new(EventContract.state_changed_required_data_fields()),
             MapSet.new(Map.keys(response["data"]))
           )
  end

  test "correlation id is omitted when incoming id is missing" do
    incoming = incoming_command("com.webui.counter.increment") |> Map.delete("id")

    assert {:ok, response} = CounterEventHandler.handle_cloudevent(incoming, nil)
    refute Map.has_key?(response["data"], "correlation_id")
  end

  test "sync emits current state without modifying count" do
    CounterServer.apply_operation(:increment)
    CounterServer.apply_operation(:increment)

    incoming = incoming_command("com.webui.counter.sync", %{"id" => "client-2"})

    assert {:ok, response} = CounterEventHandler.handle_cloudevent(incoming, nil)
    assert response["data"]["count"] == 2
    assert response["data"]["operation"] == "sync"
    assert response["data"]["correlation_id"] == "client-2"
    assert CounterServer.current_count() == 2
  end

  defp incoming_command(type, overrides \\ %{}) do
    Map.merge(
      %{
        "specversion" => EventContract.specversion(),
        "id" => "test-id",
        "source" => EventContract.client_source(),
        "type" => type,
        "data" => %{}
      },
      overrides
    )
  end

  defp ensure_counter_server do
    case Process.whereis(CounterServer) do
      nil -> start_supervised!(CounterServer)
      _pid -> :ok
    end
  end
end
