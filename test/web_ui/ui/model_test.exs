defmodule WebUi.Ui.ModelTest do
  use ExUnit.Case, async: true

  alias WebUi.Ui.Model

  test "builds deterministic defaults" do
    model_a = Model.new()
    model_b = Model.new()

    assert model_a == model_b
    assert model_a.connection_state == :disconnected
    assert model_a.runtime_context.correlation_id == "bootstrap-correlation"
    assert model_a.runtime_context.request_id == "bootstrap-request"
    assert model_a.transport.topic == "webui:runtime:v1"
    assert model_a.view_state.screen == :booting
    assert model_a.slice_state.dispatch_sequence == 0
  end

  test "accepts explicit overrides" do
    model =
      Model.new(%{
        connection_state: :connecting,
        runtime_context: %{correlation_id: "corr-201", request_id: "req-201"},
        view_state: %{screen: :custom}
      })

    assert model.connection_state == :connecting
    assert model.runtime_context.correlation_id == "corr-201"
    assert model.runtime_context.request_id == "req-201"
    assert model.view_state.screen == :custom
  end
end
