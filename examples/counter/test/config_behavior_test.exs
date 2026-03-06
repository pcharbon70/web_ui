defmodule CounterExample.ConfigBehaviorTest do
  use ExUnit.Case, async: true

  @config_path Path.expand("../config/config.exs", __DIR__)

  test "dev config uses server-agent dispatcher and boots endpoint children" do
    config = read_config!(:dev)
    web_ui_config = Keyword.fetch!(config, :web_ui)

    dispatcher_config = Keyword.get(web_ui_config, WebUi.ServerAgentDispatcher)

    assert dispatcher_config[:agents] == []
    assert dispatcher_config[:jido_servers] == []
    assert dispatcher_config[:jido_routes] == expected_jido_routes()

    assert Keyword.get(web_ui_config, WebUi.EventChannel) == nil
    assert Keyword.get(web_ui_config, :start)[:children] != []
    assert Keyword.get(web_ui_config, WebUi.Endpoint)[:server] == true
  end

  test "test config keeps web_ui children disabled and endpoint server off" do
    config = read_config!(:test)
    web_ui_config = Keyword.fetch!(config, :web_ui)

    dispatcher_config = Keyword.get(web_ui_config, WebUi.ServerAgentDispatcher)

    assert dispatcher_config[:agents] == []
    assert dispatcher_config[:jido_servers] == []
    assert dispatcher_config[:jido_routes] == expected_jido_routes()

    assert Keyword.get(web_ui_config, WebUi.EventChannel) == nil
    assert Keyword.get(web_ui_config, :start)[:children] == []
    assert Keyword.get(web_ui_config, WebUi.Endpoint)[:server] == false
  end

  test "prod config enables endpoint server and keeps dispatcher configuration" do
    previous_secret = System.get_env("SECRET_KEY_BASE")
    System.put_env("SECRET_KEY_BASE", "phase2_config_test_secret")

    on_exit(fn ->
      restore_env("SECRET_KEY_BASE", previous_secret)
    end)

    config = read_config!(:prod)
    web_ui_config = Keyword.fetch!(config, :web_ui)

    dispatcher_config = Keyword.get(web_ui_config, WebUi.ServerAgentDispatcher)

    assert dispatcher_config[:agents] == []
    assert dispatcher_config[:jido_servers] == []
    assert dispatcher_config[:jido_routes] == expected_jido_routes()

    assert Keyword.get(web_ui_config, WebUi.EventChannel) == nil
    assert Keyword.get(web_ui_config, WebUi.Endpoint)[:server] == true
    assert Keyword.get(web_ui_config, :start)[:children] == []
  end

  defp read_config!(env) do
    Config.Reader.read!(@config_path, env: env)
  end

  defp expected_jido_routes do
    [
      {"com.webui.counter.increment", {"counter-ui-increment", WebUi.Registry}},
      {"com.webui.counter.decrement", {"counter-ui-decrement", WebUi.Registry}},
      {"com.webui.counter.reset", {"counter-ui-reset", WebUi.Registry}},
      {"com.webui.counter.sync", {"counter-ui-sync", WebUi.Registry}}
    ]
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
