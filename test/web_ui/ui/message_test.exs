defmodule WebUi.Ui.MessageTest do
  use ExUnit.Case, async: true

  alias WebUi.Ui.Message

  test "builds baseline websocket message variants" do
    assert Message.websocket_recv(%{event: "recv"}).type == :ws_event_received
    assert Message.websocket_error(%{error: "boom"}).type == :ws_error_received
    assert Message.websocket_pong(%{request_id: "req"}).type == :ws_pong_received
  end

  test "builds join and interaction message variants" do
    assert Message.websocket_joined(%{topic: "webui:runtime:v1"}).type == :ws_joined
    assert Message.websocket_join_failed(%{reason: "denied"}).type == :ws_join_failed
    assert Message.widget_event(%{type: "unified.button.clicked"}).type == :widget_event
    assert Message.port_event(%{kind: "interop"}).type == :port_event
  end
end
