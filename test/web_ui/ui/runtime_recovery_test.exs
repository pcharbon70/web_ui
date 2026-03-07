defmodule WebUi.Ui.RuntimeRecoveryTest do
  use ExUnit.Case, async: true

  alias WebUi.Ui.Message
  alias WebUi.Ui.Runtime

  defp model_with_session do
    {:ok, model, _commands} =
      Runtime.init(%{
        runtime_context: %{
          correlation_id: "corr-r10",
          request_id: "req-r10",
          session_id: "sess-r10"
        }
      })

    model
  end

  test "service result success reconciles first-slice state into ready UI" do
    model = model_with_session()

    {updated_model, []} =
      Runtime.update(
        model,
        Message.websocket_recv(%{
          result: %{
            service: "ui.preferences",
            operation: "save_preferences",
            outcome: "ok",
            payload: %{ui_patch: %{notice: "Preference saved"}},
            context: %{correlation_id: "corr-r10", request_id: "req-r10", session_id: "sess-r10"}
          }
        })
      )

    assert updated_model.connection_state == :connected
    assert updated_model.view_state.screen == :ready
    assert updated_model.slice_state.status == :completed
    assert updated_model.slice_state.last_outcome == :ok
    assert hd(updated_model.view_state.notices) == "slice:ok:ui.preferences/save_preferences"
  end

  test "service result error marks retry pending when runtime error is retryable" do
    model = model_with_session()

    {updated_model, []} =
      Runtime.update(
        model,
        Message.websocket_recv(%{
          result: %{
            service: "ui.preferences",
            operation: "save_preferences",
            outcome: "error",
            error: %{
              error_code: "first_slice.retryable_dependency_error",
              category: "dependency",
              retryable: true,
              correlation_id: "corr-r10"
            },
            context: %{correlation_id: "corr-r10", request_id: "req-r10", session_id: "sess-r10"}
          }
        })
      )

    assert updated_model.connection_state == :error
    assert updated_model.last_error.error_code == "first_slice.retryable_dependency_error"
    assert updated_model.recovery_state.retry_pending? == true

    assert updated_model.recovery_state.retryable_error.error_code ==
             "first_slice.retryable_dependency_error"

    assert updated_model.slice_state.status == :failed
  end

  test "disconnection transitions to reconnecting state and emits session-resume join command" do
    model = model_with_session()

    {updated_model, [command]} =
      Runtime.update(model, Message.websocket_disconnected(%{reason: "socket_lost"}))

    assert updated_model.connection_state == :connecting
    assert updated_model.view_state.screen == :reconnecting
    assert updated_model.recovery_state.reconnect_attempts == 1

    assert updated_model.recovery_state.session_resume_topic ==
             "webui:runtime:session:sess-r10:v1"

    assert command.kind == :ws_join
    assert command.topic == "webui:runtime:session:sess-r10:v1"
  end

  test "retry_requested replays last outbound command and updates slice to retrying" do
    model = model_with_session()

    {model, [initial_command]} =
      Runtime.update(
        model,
        Message.widget_event(%{
          type: "unified.form.submitted",
          widget_id: "prefs_form",
          widget_kind: "form",
          data: %{action: "submit", preference_key: "theme", value: "dark"}
        })
      )

    {model, []} =
      Runtime.update(
        model,
        Message.websocket_recv(%{
          result: %{
            service: "ui.preferences",
            operation: "save_preferences",
            outcome: "error",
            error: %{
              error_code: "first_slice.retryable_dependency_error",
              category: "dependency",
              retryable: true,
              correlation_id: "corr-r10"
            },
            context: %{correlation_id: "corr-r10", request_id: "req-r10", session_id: "sess-r10"}
          }
        })
      )

    assert model.recovery_state.retry_pending? == true

    {updated_model, [retry_command]} = Runtime.update(model, Message.retry_requested(%{}))

    assert retry_command == initial_command
    assert updated_model.connection_state == :connecting
    assert updated_model.slice_state.status == :retrying
    assert updated_model.recovery_state.retry_pending? == false
  end

  test "cancel_requested clears retry state and marks workflow cancelled" do
    model = model_with_session()

    model = %{
      model
      | recovery_state: Map.put(model.recovery_state, :retry_pending?, true),
        slice_state: Map.put(model.slice_state, :status, :failed)
    }

    {updated_model, []} =
      Runtime.update(model, Message.cancel_requested(%{reason: "user_cancelled"}))

    assert updated_model.connection_state == :connected
    assert updated_model.slice_state.status == :cancelled
    assert updated_model.recovery_state.retry_pending? == false
    assert hd(updated_model.view_state.notices) == "cancel:user_cancelled"
  end
end
