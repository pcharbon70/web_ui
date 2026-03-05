defmodule WebUi.EventChannelServerAgentTest do
  use ExUnit.Case, async: false
  import Phoenix.ChannelTest

  alias WebUi.ServerAgents.CounterState

  @endpoint WebUi.Endpoint

  setup do
    start_endpoint_if_not_running()
    ensure_endpoint_config()
    start_pubsub_if_not_running()

    old_dispatcher_config = Application.get_env(:web_ui, WebUi.ServerAgentDispatcher)
    old_channel_config = Application.get_env(:web_ui, WebUi.EventChannel)

    Application.put_env(:web_ui, WebUi.ServerAgentDispatcher,
      agents: [WebUi.ServerAgents.CounterAgent]
    )

    channel_config =
      case old_channel_config do
        nil -> []
        config when is_list(config) -> config
        _ -> []
      end
      |> Keyword.delete(:event_handler)

    Application.put_env(:web_ui, WebUi.EventChannel, channel_config)

    :ok = CounterState.ensure_started()
    {:ok, _count} = CounterState.apply_operation(:reset)

    on_exit(fn ->
      case old_dispatcher_config do
        nil -> Application.delete_env(:web_ui, WebUi.ServerAgentDispatcher)
        config -> Application.put_env(:web_ui, WebUi.ServerAgentDispatcher, config)
      end

      case old_channel_config do
        nil -> Application.delete_env(:web_ui, WebUi.EventChannel)
        config -> Application.put_env(:web_ui, WebUi.EventChannel, config)
      end
    end)

    :ok
  end

  defp ensure_endpoint_config do
    _ = WebUi.Endpoint.config(:secret_key_base)
    :ok
  end

  defp start_endpoint_if_not_running do
    case Process.whereis(WebUi.Endpoint) do
      nil -> start_supervised!({WebUi.Endpoint, []})
      _pid -> :ok
    end
  end

  defp start_pubsub_if_not_running do
    case Process.whereis(WebUi.PubSub) do
      nil ->
        start_supervised!(
          {Phoenix.PubSub.PG2, [name: WebUi.PubSub, adapter_name: :web_ui_pubsub_test]}
        )

      _pid ->
        :ok
    end
  end

  test "counter increment is processed through server agent and broadcast as state_changed" do
    {:ok, socket} = connect(WebUi.UserSocket, %{})
    {:ok, _reply, socket} = subscribe_and_join(socket, "events:lobby", %{})

    push(socket, "cloudevent", %{
      "specversion" => "1.0",
      "id" => "client-evt-1",
      "source" => "urn:webui:test-client",
      "type" => "com.webui.counter.increment",
      "data" => %{}
    })

    assert_broadcast("cloudevent", payload)
    assert payload["specversion"] == "1.0"
    assert payload["type"] == "com.webui.counter.state_changed"
    assert payload["data"]["count"] == 1
    assert payload["data"]["operation"] == "increment"
    assert payload["data"]["correlation_id"] == "client-evt-1"
  end
end
