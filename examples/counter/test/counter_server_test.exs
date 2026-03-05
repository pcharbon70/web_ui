defmodule CounterExample.CounterServerTest do
  use ExUnit.Case, async: false

  alias CounterExample.CounterServer

  setup do
    ensure_counter_server()
    CounterServer.apply_operation(:reset)
    :ok
  end

  test "starts with count 0" do
    assert CounterServer.current_count() == 0
  end

  test "increment increases count by 1" do
    assert CounterServer.apply_operation(:increment) == 1
    assert CounterServer.current_count() == 1
  end

  test "decrement decreases count by 1" do
    CounterServer.apply_operation(:increment)
    assert CounterServer.apply_operation(:decrement) == 0
    assert CounterServer.current_count() == 0
  end

  test "reset sets count to 0" do
    CounterServer.apply_operation(:increment)
    CounterServer.apply_operation(:increment)

    assert CounterServer.apply_operation(:reset) == 0
    assert CounterServer.current_count() == 0
  end

  test "sync returns current count without changing state" do
    CounterServer.apply_operation(:increment)
    CounterServer.apply_operation(:increment)

    assert CounterServer.apply_operation(:sync) == 2
    assert CounterServer.current_count() == 2
  end

  defp ensure_counter_server do
    case Process.whereis(CounterServer) do
      nil -> start_supervised!(CounterServer)
      _pid -> :ok
    end
  end
end
