defmodule WebUi.ServerAgentDispatcherTest do
  use ExUnit.Case, async: false

  alias Jido.Signal
  alias WebUi.ServerAgentDispatcher
  alias WebUi.ServerAgents.CounterState

  setup do
    old_config = Application.get_env(:web_ui, WebUi.ServerAgentDispatcher)

    Application.put_env(:web_ui, WebUi.ServerAgentDispatcher,
      agents: [WebUi.ServerAgents.CounterAgent]
    )

    reset_counter_state!()
    :ok = CounterState.ensure_started()
    {:ok, _count} = CounterState.apply_operation(:reset)

    on_exit(fn ->
      case old_config do
        nil -> Application.delete_env(:web_ui, WebUi.ServerAgentDispatcher)
        config -> Application.put_env(:web_ui, WebUi.ServerAgentDispatcher, config)
      end
    end)

    :ok
  end

  defp reset_counter_state! do
    case Process.whereis(CounterState) do
      nil ->
        :ok

      pid ->
        Process.unlink(pid)

        try do
          GenServer.stop(pid, :normal, 1000)
        catch
          :exit, _ -> :ok
        end
    end
  end

  test "dispatches counter increment signal to counter agent" do
    signal =
      Signal.new!(%{
        id: "client-1",
        source: "urn:webui:test-client",
        type: "com.webui.counter.increment",
        data: %{}
      })

    assert {:ok, [response]} = ServerAgentDispatcher.dispatch(signal)

    assert %Signal{} = response
    assert response.type == "com.webui.counter.state_changed"
    assert response.data["count"] == 1
    assert response.data["operation"] == "increment"
    assert response.data["correlation_id"] == "client-1"
  end

  test "returns unhandled when no agent matches the signal type" do
    signal =
      Signal.new!(%{
        id: "client-2",
        source: "urn:webui:test-client",
        type: "com.webui.unknown.event",
        data: %{}
      })

    assert :unhandled = ServerAgentDispatcher.dispatch(signal)
  end
end
