defmodule CounterExample.CounterUiAgentServersTest do
  use ExUnit.Case, async: false

  alias CounterExample.{CounterServer, CounterUiAgentServers, EventContract}
  alias Jido.Signal
  alias WebUi.ServerAgentDispatcher

  setup do
    {:ok, _apps} = Application.ensure_all_started(:counter_example)
    :ok = ensure_ui_agents_started!()
    :ok = CounterServer.ensure_started()
    {:ok, _count} = CounterServer.reset()
    :ok
  end

  test "starts one jido agent server per counter command" do
    assert CounterUiAgentServers.server_ids() == [
             "counter-ui-increment",
             "counter-ui-decrement",
             "counter-ui-reset",
             "counter-ui-sync"
           ]

    Enum.each(CounterUiAgentServers.server_ids(), fn server_id ->
      assert {:ok, pid} = Jido.resolve_pid({server_id, WebUi.Registry})
      assert Process.alive?(pid)
    end)
  end

  test "dispatches each counter command through routed jido ui agents" do
    assert {:ok, [increment]} =
             dispatch_command("com.webui.counter.increment", "client-increment")

    assert increment.type == EventContract.state_changed_type()
    assert increment.source == EventContract.server_source()
    assert increment.data["count"] == 1
    assert increment.data["operation"] == "increment"
    assert increment.data["correlation_id"] == "client-increment"

    assert {:ok, [decrement]} =
             dispatch_command("com.webui.counter.decrement", "client-decrement")

    assert decrement.data["count"] == 0
    assert decrement.data["operation"] == "decrement"
    assert decrement.data["correlation_id"] == "client-decrement"

    assert {:ok, [sync]} = dispatch_command("com.webui.counter.sync", "client-sync")
    assert sync.data["count"] == 0
    assert sync.data["operation"] == "sync"
    assert sync.data["correlation_id"] == "client-sync"

    assert {:ok, [reset]} = dispatch_command("com.webui.counter.reset", "client-reset")
    assert reset.data["count"] == 0
    assert reset.data["operation"] == "reset"
    assert reset.data["correlation_id"] == "client-reset"
  end

  defp dispatch_command(type, correlation_id) do
    signal =
      Signal.new!(%{
        id: correlation_id,
        source: EventContract.client_source(),
        type: type,
        data: %{}
      })

    ServerAgentDispatcher.dispatch(signal)
  end

  defp ensure_ui_agents_started! do
    Enum.each(CounterUiAgentServers.child_specs(), fn spec ->
      server_id = spec.id |> elem(1)

      case Jido.resolve_pid({server_id, WebUi.Registry}) do
        {:ok, _pid} ->
          :ok

        {:error, :server_not_found} ->
          start_supervised!(spec)
      end
    end)

    :ok
  end
end
