defmodule CounterExample.CounterAgentTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias CounterExample.{CounterAgent, CounterServer, EventContract}
  alias Jido.Signal

  setup do
    :ok = CounterServer.ensure_started()
    {:ok, _count} = CounterServer.reset()
    :ok
  end

  test "handles known counter command types" do
    assert CounterAgent.handles?(new_signal("com.webui.counter.increment"))
    assert CounterAgent.handles?(new_signal("com.webui.counter.decrement"))
    assert CounterAgent.handles?(new_signal("com.webui.counter.reset"))
    assert CounterAgent.handles?(new_signal("com.webui.counter.sync"))
    refute CounterAgent.handles?(new_signal("com.webui.counter.unknown"))
  end

  test "returns state_changed signal for increment command" do
    assert {:ok, response} = CounterAgent.handle_signal(new_signal("com.webui.counter.increment"))
    assert %Signal{} = response
    assert response.type == EventContract.state_changed_type()
    assert response.source == EventContract.server_source()
    assert response.data["count"] == 1
    assert response.data["operation"] == "increment"
    assert response.data["correlation_id"] == "client-1"
  end

  test "returns unhandled for unknown command types" do
    assert :unhandled = CounterAgent.handle_signal(new_signal("com.webui.counter.unknown"))
  end

  test "returns error for malformed signal data" do
    signal = new_signal("com.webui.counter.increment", %{data: "invalid"})

    assert CounterAgent.handle_signal(signal) ==
             {:error, {:invalid_signal_data, "invalid"}}
  end

  test "logs structured fields for command errors" do
    log =
      capture_log(fn ->
        assert CounterAgent.handle_signal(new_signal("com.webui.counter.increment", %{data: 123})) ==
                 {:error, {:invalid_signal_data, 123}}
      end)

    assert log =~ "counter_command_error"
    assert log =~ "type=com.webui.counter.increment"
    assert log =~ "reason={:invalid_signal_data, 123}"
    assert log =~ "correlation_id=\"client-1\""
  end

  test "emits telemetry for successful command processing" do
    event_name = [:counter_example, :counter_agent, :command, :stop]
    attach_telemetry_handler(event_name)

    assert {:ok, _response} =
             CounterAgent.handle_signal(new_signal("com.webui.counter.increment"))

    assert_receive {:telemetry, ^event_name, measurements, metadata}, 1_000
    assert is_integer(measurements.duration)
    assert metadata.type == "com.webui.counter.increment"
    assert metadata.operation == :increment
    assert metadata.count == 1
    assert metadata.correlation_id == "client-1"
  end

  test "emits telemetry for error command paths" do
    event_name = [:counter_example, :counter_agent, :command, :error]
    attach_telemetry_handler(event_name)

    assert CounterAgent.handle_signal(new_signal("com.webui.counter.increment", %{data: 123})) ==
             {:error, {:invalid_signal_data, 123}}

    assert_receive {:telemetry, ^event_name, measurements, metadata}, 1_000
    assert is_integer(measurements.duration)
    assert metadata.type == "com.webui.counter.increment"
    assert metadata.reason == {:invalid_signal_data, 123}
    assert metadata.correlation_id == "client-1"
  end

  test "returns an error when the input is not a signal struct" do
    assert CounterAgent.handle_signal(%{}) == {:error, :invalid_signal}
  end

  defp new_signal(type, overrides \\ %{}) do
    base =
      %{
        id: "client-1",
        source: EventContract.client_source(),
        type: type,
        data: %{}
      }
      |> Map.merge(overrides)

    Signal.new!(base)
  end

  defp attach_telemetry_handler(event_name) do
    handler_id = "counter-agent-test-#{System.unique_integer([:positive, :monotonic])}"

    :ok =
      :telemetry.attach(
        handler_id,
        event_name,
        fn event, measurements, metadata, owner ->
          send(owner, {:telemetry, event, measurements, metadata})
        end,
        self()
      )

    on_exit(fn ->
      :telemetry.detach(handler_id)
    end)
  end
end
