defmodule WebUi.ChannelObservabilityTest do
  use ExUnit.Case, async: true

  alias WebUi.Channel
  alias WebUi.Observability.RuntimeEvent

  defp valid_payload do
    %{
      event: %{
        specversion: "1.0",
        id: "evt-711",
        source: "webui.test",
        type: "runtime.command",
        data: %{action: "save"},
        correlation_id: "corr-711",
        request_id: "req-711"
      }
    }
  end

  test "transport ingress and egress emissions produce valid runtime event envelopes" do
    parent = self()

    assert {:ok, _response} =
             Channel.handle_client_message(
               "webui:runtime:v1",
               "runtime.event.send.v1",
               valid_payload(),
               observability_fun: fn event -> send(parent, {:obs_event, event}) end
             )

    assert_received {:obs_event, ingress_event}
    assert ingress_event.event_name == "runtime.transport.ingress.v1"
    assert :ok == RuntimeEvent.validate(ingress_event)

    assert_received {:obs_event, egress_event}
    assert egress_event.event_name == "runtime.transport.egress.v1"
    assert :ok == RuntimeEvent.validate(egress_event)
  end

  test "decode failures emit typed observability error events" do
    parent = self()

    bad_payload = %{event: %{specversion: "1.0", id: "evt-712"}}

    assert {:ok, response} =
             Channel.handle_client_message(
               "webui:runtime:v1",
               "runtime.event.send.v1",
               bad_payload,
               observability_fun: fn event -> send(parent, {:obs_event, event}) end
             )

    assert response.event_name == "runtime.event.error.v1"

    events =
      Stream.repeatedly(fn ->
        receive do
          {:obs_event, event} -> event
        after
          20 -> :done
        end
      end)
      |> Enum.take_while(&(&1 != :done))

    assert Enum.any?(events, &(&1.event_name == "runtime.transport.decode_failed.v1"))
    assert Enum.any?(events, &(&1.event_name == "runtime.transport.egress.v1" and &1.outcome == "error"))
    assert Enum.all?(events, &(RuntimeEvent.validate(&1) == :ok))
  end
end
