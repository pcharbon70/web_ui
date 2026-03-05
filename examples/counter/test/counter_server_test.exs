defmodule CounterExample.CounterServerTest do
  use ExUnit.Case, async: false

  alias CounterExample.CounterServer

  setup do
    :ok = CounterServer.ensure_started()
    {:ok, _count} = CounterServer.reset()
    :ok
  end

  test "starts with count 0" do
    assert CounterServer.current_count() == {:ok, 0}
  end

  test "increment increases count by 1" do
    assert CounterServer.apply_operation(:increment) == {:ok, 1}
    assert CounterServer.current_count() == {:ok, 1}
  end

  test "decrement decreases count by 1" do
    CounterServer.apply_operation(:increment)
    assert CounterServer.apply_operation(:decrement) == {:ok, 0}
    assert CounterServer.current_count() == {:ok, 0}
  end

  test "reset sets count to 0" do
    CounterServer.apply_operation(:increment)
    CounterServer.apply_operation(:increment)

    assert CounterServer.reset() == {:ok, 0}
    assert CounterServer.current_count() == {:ok, 0}
  end

  test "sync returns current count without changing state" do
    CounterServer.apply_operation(:increment)
    CounterServer.apply_operation(:increment)

    assert CounterServer.sync() == {:ok, 2}
    assert CounterServer.current_count() == {:ok, 2}
  end

  test "returns an error for unsupported operations" do
    assert CounterServer.apply_operation(:unsupported) ==
             {:error, {:unsupported_operation, :unsupported}}
  end

  test "recovers after an unexpected process crash" do
    CounterServer.apply_operation(:increment)
    pid = Process.whereis(CounterServer)
    Process.exit(pid, :kill)

    wait_for_server_restart()

    assert {:ok, _count} = CounterServer.current_count()
    assert CounterServer.apply_operation(:increment) in [{:ok, 1}, {:ok, 2}]
  end

  test "handles concurrent increment calls deterministically" do
    tasks =
      for _ <- 1..100 do
        Task.async(fn -> CounterServer.apply_operation(:increment) end)
      end

    results = Enum.map(tasks, &Task.await(&1, 5_000))
    assert Enum.all?(results, &match?({:ok, _count}, &1))
    assert CounterServer.current_count() == {:ok, 100}
  end

  test "emits telemetry for successful operations" do
    event_name = [:counter_example, :counter_server, :operation, :stop]
    attach_telemetry_handler(event_name)

    assert CounterServer.apply_operation(:increment) == {:ok, 1}

    assert_receive {:telemetry, ^event_name, measurements, metadata}, 1_000
    assert is_integer(measurements.duration)
    assert metadata.operation == :increment
    assert metadata.count == 1
  end

  test "emits telemetry for operation errors" do
    event_name = [:counter_example, :counter_server, :operation, :error]
    attach_telemetry_handler(event_name)

    assert CounterServer.apply_operation(:unsupported) ==
             {:error, {:unsupported_operation, :unsupported}}

    assert_receive {:telemetry, ^event_name, measurements, metadata}, 1_000
    assert is_integer(measurements.duration)
    assert metadata.operation == :unsupported
    assert metadata.reason == {:unsupported_operation, :unsupported}
  end

  defp wait_for_server_restart do
    Enum.reduce_while(1..100, :timeout, fn _, _acc ->
      case Process.whereis(CounterServer) do
        nil ->
          Process.sleep(10)
          {:cont, :timeout}

        _pid ->
          {:halt, :ok}
      end
    end)

    :ok
  end

  defp attach_telemetry_handler(event_name) do
    handler_id = "counter-server-test-#{System.unique_integer([:positive, :monotonic])}"

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
