defmodule WebUi.Ui.RuntimeReplayControlTest do
  use ExUnit.Case, async: true

  alias WebUi.Ui.Message
  alias WebUi.Ui.Runtime

  defp model_with_replay_entries do
    {:ok, model, _commands} =
      Runtime.init(%{
        runtime_context: %{
          correlation_id: "corr-replay-ctl",
          request_id: "req-replay-ctl",
          session_id: "sess-replay-ctl"
        }
      })

    {model, [first_dispatch]} =
      Runtime.update(
        model,
        Message.widget_event(%{
          type: "unified.button.clicked",
          widget_id: "save_button",
          widget_kind: "button",
          data: %{action: "save"}
        })
      )

    first_turn_id = first_dispatch.payload.event["data"]["turn_id"]

    {model, []} =
      Runtime.update(
        model,
        Message.websocket_recv(%{
          result: %{
            service: "ui.preferences",
            operation: "save_preferences",
            outcome: "ok",
            payload: %{turn_id: first_turn_id},
            context: %{
              correlation_id: "corr-replay-ctl",
              request_id: "req-replay-ctl",
              session_id: "sess-replay-ctl"
            }
          }
        })
      )

    {model, [second_dispatch]} =
      Runtime.update(
        model,
        Message.widget_event(%{
          type: "unified.button.clicked",
          widget_id: "save_button",
          widget_kind: "button",
          data: %{action: "publish"}
        })
      )

    second_turn_id = second_dispatch.payload.event["data"]["turn_id"]

    {model, []} =
      Runtime.update(
        model,
        Message.websocket_recv(%{
          result: %{
            service: "ui.preferences",
            operation: "save_preferences",
            outcome: "ok",
            payload: %{turn_id: second_turn_id},
            context: %{
              correlation_id: "corr-replay-ctl",
              request_id: "req-replay-ctl",
              session_id: "sess-replay-ctl"
            }
          }
        })
      )

    model
  end

  test "replay_snapshot_requested stores deterministic snapshot diagnostics" do
    model = model_with_replay_entries()

    assert model.recovery_state.replay_cursor == 4
    assert length(model.recovery_state.replay_log.entries) == 4

    {updated_model, []} =
      Runtime.update(model, Message.replay_snapshot_requested(%{from_cursor: 2}))

    snapshot = updated_model.recovery_state.last_replay_snapshot

    assert snapshot.cursor == 4
    assert snapshot.entry_count == 2
    assert Enum.map(snapshot.entries, & &1.cursor) == [3, 4]
    assert hd(updated_model.view_state.notices) == "replay:snapshot:2:4"
    assert hd(updated_model.inbound_history).event == :replay_snapshot_requested
  end

  test "replay_export_requested stores deterministic export payloads" do
    model = model_with_replay_entries()

    {updated_model, []} =
      Runtime.update(
        model,
        Message.replay_export_requested(%{include_snapshot: true, from_cursor: 2, limit: 1})
      )

    replay_export = updated_model.recovery_state.last_replay_export
    replay_snapshot = updated_model.recovery_state.last_replay_snapshot

    assert replay_export.format == "web_ui.replay_log.export.v1"
    assert replay_export.cursor == 4
    assert length(replay_export.entries) == 4
    assert replay_snapshot.entry_count == 1
    assert Enum.map(replay_snapshot.entries, & &1.cursor) == [3]
    assert hd(updated_model.view_state.notices) == "replay:export:4:4"
    assert hd(updated_model.inbound_history).event == :replay_export_requested
  end

  test "replay_compaction_requested preserves cursor continuity while retaining trailing entries" do
    model = model_with_replay_entries()

    {updated_model, []} =
      Runtime.update(model, Message.replay_compaction_requested(%{keep_last: 2}))

    replay_log = updated_model.recovery_state.replay_log

    assert updated_model.recovery_state.replay_cursor == 4
    assert updated_model.recovery_state.replay_retention_limit == 2
    assert Enum.map(replay_log.entries, & &1.cursor) == [3, 4]
    assert Enum.map(replay_log.entries, & &1.direction) == [:outbound, :inbound]

    assert String.starts_with?(
             updated_model.recovery_state.last_replay_checkpoint_id,
             "replay-000004-"
           )

    assert hd(updated_model.view_state.notices) == "replay:compact:2:2"
    assert hd(updated_model.inbound_history).event == :replay_compaction_requested
  end

  test "replay_compaction_requested fails closed on invalid keep_last options" do
    model = model_with_replay_entries()

    {updated_model, commands} =
      Runtime.update(model, Message.replay_compaction_requested(%{keep_last: -1}))

    assert commands == []
    assert updated_model.last_error.error_code == "replay_log.invalid_compaction_options"
  end
end
