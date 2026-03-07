defmodule WebUi.CloudEventTest do
  use ExUnit.Case, async: true

  alias WebUi.CloudEvent
  alias WebUi.TypedError

  test "validates required cloud event fields" do
    envelope = %{
      specversion: "1.0",
      id: "evt-1",
      source: "webui.test",
      type: "runtime.test",
      data: %{},
      correlation_id: "corr-1",
      request_id: "req-1"
    }

    assert {:ok, validated} = CloudEvent.validate_envelope(envelope)
    assert validated.specversion == "1.0"
    assert validated.id == "evt-1"
  end

  test "rejects missing required fields" do
    assert {:error, %TypedError{} = error} =
             CloudEvent.validate_envelope(%{specversion: "1.0", source: "webui.test"})

    assert error.error_code == "cloudevent.missing_required_fields"
    assert :id in error.details[:missing_fields]
    assert :type in error.details[:missing_fields]
  end

  test "extracts runtime context" do
    envelope = %{correlation_id: "corr-1", request_id: "req-1", client_id: "client-1"}

    assert {:ok, context} = CloudEvent.extract_context(envelope)
    assert context.correlation_id == "corr-1"
    assert context.request_id == "req-1"
    assert context.client_id == "client-1"
  end

  test "fails when correlation_id is missing" do
    assert {:error, %TypedError{} = error} = CloudEvent.extract_context(%{request_id: "req-1"})
    assert error.error_code == "cloudevent.missing_correlation_id"
  end

  test "fails when request_id is missing" do
    assert {:error, %TypedError{} = error} = CloudEvent.extract_context(%{correlation_id: "corr-1"})
    assert error.error_code == "cloudevent.missing_request_id"
  end
end
