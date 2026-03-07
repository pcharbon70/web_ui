defmodule WebUi.Persistence.ReplayLogTest do
  use ExUnit.Case, async: true

  alias WebUi.Persistence.ReplayLog
  alias WebUi.TypedError

  test "append builds deterministic cursor progression and checkpoints" do
    assert ReplayLog.new() == %{cursor: 0, entries: [], last_checkpoint_id: nil}

    {:ok, log} =
      ReplayLog.new()
      |> ReplayLog.append(%{
        direction: :outbound,
        event: "runtime.event.send.v1",
        metadata: %{dispatch_sequence: 1, turn_id: "turn-000001"}
      })

    assert log.cursor == 1
    assert length(log.entries) == 1
    assert hd(log.entries).cursor == 1
    assert hd(log.entries).direction == :outbound
    assert hd(log.entries).event == "runtime.event.send.v1"
    assert is_binary(log.last_checkpoint_id)
    assert String.starts_with?(log.last_checkpoint_id, "replay-000001-")

    {:ok, log2} =
      ReplayLog.append(log, %{
        direction: :inbound,
        event: :ws_result_received,
        metadata: %{outcome: "ok", turn_id: "turn-000001"}
      })

    assert log2.cursor == 2
    assert Enum.map(log2.entries, & &1.cursor) == [1, 2]
    assert String.starts_with?(log2.last_checkpoint_id, "replay-000002-")
  end

  test "entries_since returns deterministic slices from a cursor" do
    {:ok, log1} =
      ReplayLog.new()
      |> ReplayLog.append(%{direction: :outbound, event: "a", metadata: %{n: 1}})

    {:ok, log2} =
      ReplayLog.append(log1, %{direction: :inbound, event: "b", metadata: %{n: 2}})

    {:ok, log3} =
      ReplayLog.append(log2, %{direction: :outbound, event: "c", metadata: %{n: 3}})

    assert Enum.map(ReplayLog.entries_since(log3, 0), & &1.event) == ["a", "b", "c"]
    assert Enum.map(ReplayLog.entries_since(log3, 1), & &1.event) == ["b", "c"]
    assert Enum.map(ReplayLog.entries_since(log3, 2), & &1.event) == ["c"]
    assert ReplayLog.entries_since(log3, 3) == []
  end

  test "fails closed for invalid logs and malformed entries" do
    assert {:error, %TypedError{} = invalid_log_error} =
             ReplayLog.append(%{cursor: -1, entries: []}, %{direction: :outbound, event: "x"})

    assert invalid_log_error.error_code == "replay_log.invalid_log_state"

    assert {:error, %TypedError{} = invalid_entry_error} =
             ReplayLog.append(ReplayLog.new(), %{direction: :sideways, event: ""})

    assert invalid_entry_error.error_code == "replay_log.invalid_entry_shape"
  end
end
