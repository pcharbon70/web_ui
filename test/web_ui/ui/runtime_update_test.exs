defmodule WebUi.Ui.RuntimeUpdateTest do
  use ExUnit.Case, async: true

  alias WebUi.Ui.Message
  alias WebUi.Ui.Runtime

  defp booted_model do
    {:ok, model, _commands} =
      Runtime.init(%{runtime_context: %{correlation_id: "corr-220", request_id: "req-220"}})

    model
  end

  test "widget events map to canonical runtime.event.send.v1 commands" do
    model = booted_model()

    widget_msg =
      Message.widget_event(%{
        type: "unified.button.clicked",
        widget_id: "save_button",
        widget_kind: "button",
        data: %{action: "save"}
      })

    {updated_model, [command]} = Runtime.update(model, widget_msg)

    assert command.kind == :ws_push
    assert command.event_name == "runtime.event.send.v1"
    assert command.payload.event["type"] == "unified.button.clicked"
    assert command.payload.event["correlation_id"] == "corr-220"
    assert command.payload.event["request_id"] == "req-220"
    assert List.last(updated_model.outbound_queue) == command
  end

  test "invalid widget events fail closed with typed ui error state" do
    model = booted_model()

    widget_msg =
      Message.widget_event(%{
        type: "unified.button.clicked",
        widget_kind: "button",
        data: "invalid"
      })

    {updated_model, commands} = Runtime.update(model, widget_msg)

    assert commands == []
    assert updated_model.last_error.error_code in ["ui.widget_event.missing_fields", "ui.widget_event.invalid_data"]
    assert updated_model.view_state.ui_error.code == updated_model.last_error.error_code
  end

  test "inbound runtime.recv updates model deterministically" do
    model = booted_model()

    recv_msg =
      Message.websocket_recv(%{
        event: %{
          specversion: "1.0",
          id: "evt-220",
          source: "webui.runtime",
          type: "runtime.result",
          data: %{status: "ok"},
          correlation_id: "corr-220",
          request_id: "req-220"
        }
      })

    {updated_model, commands} = Runtime.update(model, recv_msg)

    assert commands == []
    assert updated_model.connection_state == :connected
    assert hd(updated_model.inbound_history).event == :ws_event_received
    assert hd(updated_model.view_state.notices) == "recv:runtime.result"
  end

  test "inbound runtime.error sets typed ui-visible error" do
    model = booted_model()

    error_msg =
      Message.websocket_error(%{
        error: %{
          error_code: "runtime.validation_failed",
          category: "validation",
          retryable: false,
          correlation_id: "corr-220"
        }
      })

    {updated_model, commands} = Runtime.update(model, error_msg)

    assert commands == []
    assert updated_model.connection_state == :error
    assert updated_model.last_error.error_code == "runtime.validation_failed"
    assert updated_model.view_state.ui_error.code == "runtime.validation_failed"
  end

  test "inbound runtime.pong updates keepalive marker" do
    model = booted_model()

    pong_msg = Message.websocket_pong(%{request_id: "req-220"})
    {updated_model, commands} = Runtime.update(model, pong_msg)

    assert commands == []
    assert updated_model.connection_state == :connected
    assert updated_model.transport.last_pong_at == "req-220"
    assert hd(updated_model.inbound_history).event == :ws_pong_received
  end
end
