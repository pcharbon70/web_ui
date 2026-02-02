defmodule WebUi.Agent.EventsTest do
  use ExUnit.Case, async: true

  alias WebUi.Agent.Events
  alias WebUi.CloudEvent

  @moduletag :agent_events
  @moduletag :unit

  describe "5.4.1 - ok/1 creates success event" do
    test "creates event with correct type and source" do
      event =
        Events.ok(
          agent_name: "calculator",
          data: %{result: 42}
        )

      assert event.type == "com.webui.agent.calculator.ok"
      assert event.source == "urn:webui:agents:calculator"
      assert event.data == %{result: 42}
      assert event.time != nil
    end

    test "accepts atom agent name" do
      event =
        Events.ok(
          agent_name: :my_agent,
          data: %{}
        )

      assert event.source == "urn:webui:agents:my_agent"
    end

    test "includes correlation ID when provided" do
      event =
        Events.ok(
          agent_name: "processor",
          data: %{count: 10},
          correlation_id: "req-123"
        )

      assert event.extensions["correlationid"] == "req-123"
    end
  end

  describe "5.4.2 - error/1 creates error event" do
    test "creates event with correct type and source" do
      event =
        Events.error(
          agent_name: "calculator",
          data: %{message: "Division by zero", code: "div_zero"}
        )

      assert event.type == "com.webui.agent.calculator.error"
      assert event.source == "urn:webui:agents:calculator"
      assert event.data.message == "Division by zero"
      assert event.data.code == "div_zero"
    end

    test "includes correlation ID when provided" do
      event =
        Events.error(
          agent_name: "validator",
          data: %{message: "Invalid"},
          correlation_id: "req-456"
        )

      assert event.extensions["correlationid"] == "req-456"
    end

    test "includes subject when provided" do
      event =
        Events.error(
          agent_name: "processor",
          data: %{message: "Failed"},
          subject: "task-789"
        )

      assert event.subject == "task-789"
    end
  end

  describe "5.4.3 - progress/2 creates status event" do
    test "creates progress event with percent calculated" do
      event =
        Events.progress(
          agent_name: "importer",
          current: 50,
          total: 100
        )

      assert event.type == "com.webui.agent.importer.progress"
      assert event.data.current == 50
      assert event.data.total == 100
      assert event.data.percent == 50
    end

    test "calculates percent correctly for different values" do
      event =
        Events.progress(
          agent_name: "processor",
          current: 25,
          total: 200
        )

      assert event.data.percent == 13
    end

    test "handles zero total" do
      event =
        Events.progress(
          agent_name: "processor",
          current: 10,
          total: 0
        )

      assert event.data.percent == 0
    end

    test "includes message when provided" do
      event =
        Events.progress(
          agent_name: "importer",
          current: 50,
          total: 100,
          message: "Processing..."
        )

      assert event.data.message == "Processing..."
    end

    test "merges additional data" do
      event =
        Events.progress(
          agent_name: "importer",
          current: 50,
          total: 100,
          data: %{filename: "data.csv"}
        )

      assert event.data.filename == "data.csv"
      assert event.data.current == 50
      assert event.data.total == 100
    end
  end

  describe "5.4.4 - source URIs are correct" do
    test "ok event has correct source" do
      event = Events.ok(agent_name: "test-agent", data: %{})
      assert event.source == "urn:webui:agents:test-agent"
    end

    test "error event has correct source" do
      event = Events.error(agent_name: "test-agent", data: %{})
      assert event.source == "urn:webui:agents:test-agent"
    end

    test "progress event has correct source" do
      event = Events.progress(agent_name: "test-agent", current: 1, total: 10)
      assert event.source == "urn:webui:agents:test-agent"
    end

    test "data_changed event has correct source" do
      event =
        Events.data_changed(
          agent_name: "test-agent",
          entity_type: "user",
          entity_id: "123",
          data: %{}
        )

      assert event.source == "urn:webui:agents:test-agent"
    end
  end

  describe "5.4.5 - correlation IDs link requests" do
    test "correlation ID is preserved in ok event" do
      correlation_id = "req-abc-123"

      event =
        Events.ok(
          agent_name: "processor",
          data: %{},
          correlation_id: correlation_id
        )

      assert Events.get_correlation_id(event) == correlation_id
    end

    test "correlation ID is preserved in error event" do
      correlation_id = "req-xyz-789"

      event =
        Events.error(
          agent_name: "processor",
          data: %{},
          correlation_id: correlation_id
        )

      assert Events.get_correlation_id(event) == correlation_id
    end

    test "correlation ID is preserved in progress event" do
      correlation_id = "req-prog-111"

      event =
        Events.progress(
          agent_name: "processor",
          current: 1,
          total: 10,
          correlation_id: correlation_id
        )

      assert Events.get_correlation_id(event) == correlation_id
    end

    test "get_correlation_id returns nil when not present" do
      event = Events.ok(agent_name: "processor", data: %{})
      assert Events.get_correlation_id(event) == nil
    end
  end

  describe "5.4.6 - events are valid CloudEvents" do
    test "ok event validates successfully" do
      event = Events.ok(agent_name: "test", data: %{})
      assert CloudEvent.validate(event) == :ok
    end

    test "error event validates successfully" do
      event = Events.error(agent_name: "test", data: %{})
      assert CloudEvent.validate(event) == :ok
    end

    test "progress event validates successfully" do
      event = Events.progress(agent_name: "test", current: 1, total: 10)
      assert CloudEvent.validate(event) == :ok
    end

    test "data_changed event validates successfully" do
      event =
        Events.data_changed(
          agent_name: "test",
          entity_type: "user",
          entity_id: "123",
          data: %{}
        )

      assert CloudEvent.validate(event) == :ok
    end

    test "validation_error event validates successfully" do
      event = Events.validation_error(agent_name: "test", errors: [])
      assert CloudEvent.validate(event) == :ok
    end
  end

  describe "5.4.7 - batch events work correctly" do
    test "batch returns list of events" do
      events =
        Events.batch([
          Events.ok(agent_name: "worker-1", data: %{task: "done"}),
          Events.ok(agent_name: "worker-2", data: %{task: "done"}),
          Events.ok(agent_name: "worker-3", data: %{task: "done"})
        ])

      assert length(events) == 3
      assert Enum.all?(events, &CloudEvent.cloudevent?/1)
    end

    test "batch events can be dispatched" do
      events =
        Events.batch([
          Events.ok(agent_name: "worker-1", data: %{index: 1}),
          Events.ok(agent_name: "worker-2", data: %{index: 2})
        ])

      assert length(events) == 2
      assert hd(events).data.index == 1
      assert List.last(events).data.index == 2
    end
  end

  describe "5.4.8 - event filtering helpers" do
    test "matches? filters by type" do
      event = Events.ok(agent_name: "calculator", data: %{})

      assert Events.matches?(event, type: "com.webui.agent.calculator.ok")
      assert Events.matches?(event, type: "com.webui.agent.*")
      refute Events.matches?(event, type: "com.webui.agent.other.*")
    end

    test "matches? filters by source" do
      event = Events.ok(agent_name: "calculator", data: %{})

      assert Events.matches?(event, source: "urn:webui:agents:calculator")
      refute Events.matches?(event, source: "urn:webui:agents:other")
    end

    test "matches? filters by agent_name" do
      event = Events.ok(agent_name: "calculator", data: %{})

      assert Events.matches?(event, agent_name: "calculator")
      assert Events.matches?(event, agent_name: :calculator)
      refute Events.matches?(event, agent_name: "other")
    end

    test "matches? filters by correlation_id presence" do
      event_with_corr =
        Events.ok(
          agent_name: "test",
          data: %{},
          correlation_id: "req-123"
        )

      event_without_corr = Events.ok(agent_name: "test", data: %{})

      assert Events.matches?(event_with_corr, has_correlation_id: true)
      refute Events.matches?(event_with_corr, has_correlation_id: false)
      refute Events.matches?(event_without_corr, has_correlation_id: true)
      assert Events.matches?(event_without_corr, has_correlation_id: false)
    end

    test "matches? filters by min_data keys" do
      event =
        Events.ok(
          agent_name: "test",
          data: %{result: 42, timestamp: "2024-01-01"}
        )

      assert Events.matches?(event, min_data: [:result])
      assert Events.matches?(event, min_data: [:result, :timestamp])
      refute Events.matches?(event, min_data: [:result, :missing])
    end

    test "matches? combines multiple filters" do
      event =
        Events.ok(
          agent_name: "calculator",
          data: %{result: 42},
          correlation_id: "req-123"
        )

      assert Events.matches?(event, agent_name: "calculator", has_correlation_id: true)
      refute Events.matches?(event, agent_name: "calculator", has_correlation_id: false)
      refute Events.matches?(event, agent_name: "other", has_correlation_id: true)
    end
  end

  describe "get_agent_name" do
    test "extracts agent name from agent URN source" do
      event = Events.ok(agent_name: "my-agent", data: %{})
      assert Events.get_agent_name(event) == "my-agent"
    end

    test "returns nil for non-URN source" do
      event = CloudEvent.new!(source: "/other-source", type: "com.test", data: %{})
      assert Events.get_agent_name(event) == nil
    end
  end

  describe "data_changed" do
    test "creates data changed event with entity info" do
      event =
        Events.data_changed(
          agent_name: "user-manager",
          entity_type: "user",
          entity_id: "123",
          data: %{status: "active"}
        )

      assert event.type == "com.webui.agent.user-manager.data_changed"
      assert event.data.entity_type == "user"
      assert event.data.entity_id == "123"
      assert event.data.changes == %{status: "active"}
      assert event.subject == "123"
    end

    test "includes action when provided" do
      event =
        Events.data_changed(
          agent_name: "document-store",
          entity_type: "document",
          entity_id: "doc-456",
          data: %{title: "New Title"},
          action: "updated"
        )

      assert event.data.action == "updated"
    end
  end

  describe "validation_error" do
    test "creates validation error event with error list" do
      event =
        Events.validation_error(
          agent_name: "form-validator",
          errors: [
            %{field: "email", message: "Invalid format"},
            %{field: "password", message: "Too short"}
          ]
        )

      assert event.type == "com.webui.agent.form-validator.validation_error"
      assert event.data.error_count == 2
      assert length(event.data.errors) == 2
    end

    test "normalizes string errors" do
      event =
        Events.validation_error(
          agent_name: "validator",
          errors: ["Error 1", "Error 2"]
        )

      assert event.data.errors == [
               %{message: "Error 1"},
               %{message: "Error 2"}
             ]
    end

    test "handles single string error" do
      event =
        Events.validation_error(
          agent_name: "validator",
          errors: "Single error"
        )

      assert event.data.errors == [%{message: "Single error"}]
    end
  end

  describe "custom" do
    test "creates custom event type" do
      event =
        Events.custom(
          agent_name: "calculator",
          event_type: "calculation_started",
          data: %{expression: "2 + 2"}
        )

      assert event.type == "com.webui.agent.calculator.calculation_started"
      assert event.data.expression == "2 + 2"
    end

    test "custom event includes correlation ID" do
      event =
        Events.custom(
          agent_name: "processor",
          event_type: "custom_event",
          data: %{},
          correlation_id: "req-custom"
        )

      assert event.extensions["correlationid"] == "req-custom"
    end
  end

  describe "extensions" do
    test "custom extensions are included in event" do
      event =
        Events.ok(
          agent_name: "test",
          data: %{},
          extensions: %{"custom-key" => "custom-value", "priority" => 1}
        )

      assert event.extensions["custom-key"] == "custom-value"
      assert event.extensions["priority"] == 1
    end

    test "correlation_id and extensions merge correctly" do
      event =
        Events.ok(
          agent_name: "test",
          data: %{},
          correlation_id: "req-123",
          extensions: %{"custom-key" => "custom-value"}
        )

      assert event.extensions["correlationid"] == "req-123"
      assert event.extensions["custom-key"] == "custom-value"
    end
  end
end
