defmodule WebUi.SignalBridgeTest do
  use ExUnit.Case, async: true

  alias Jido.Signal
  alias WebUi.SignalBridge

  describe "from_cloudevent_map/1" do
    test "converts wire-format cloud event to jido signal" do
      event = %{
        "specversion" => "1.0",
        "id" => "evt-1",
        "source" => "urn:webui:test",
        "type" => "com.webui.counter.increment",
        "data" => %{"count" => 1}
      }

      assert {:ok, %Signal{} = signal} = SignalBridge.from_cloudevent_map(event)
      assert signal.specversion == "1.0.2"
      assert signal.id == "evt-1"
      assert signal.source == "urn:webui:test"
      assert signal.type == "com.webui.counter.increment"
      assert signal.data == %{"count" => 1}
    end
  end

  describe "to_cloudevent_map/1" do
    test "converts jido signal to wire-format cloud event map" do
      signal =
        Signal.new!(%{
          specversion: "1.0.2",
          id: "sig-1",
          source: "urn:webui:agent:test",
          type: "com.webui.counter.state_changed",
          time: "2026-02-17T00:00:00Z",
          data: %{"count" => 2}
        })

      event = SignalBridge.to_cloudevent_map(signal)

      assert event["specversion"] == "1.0"
      assert event["id"] == "sig-1"
      assert event["source"] == "urn:webui:agent:test"
      assert event["type"] == "com.webui.counter.state_changed"
      assert event["time"] == "2026-02-17T00:00:00Z"
      assert event["data"] == %{"count" => 2}
    end
  end
end
