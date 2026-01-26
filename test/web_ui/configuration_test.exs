defmodule WebUi.ConfigurationTest do
  use ExUnit.Case, async: true

  @moduletag :configuration

  describe "config/config.exs" do
    test "has logger configuration" do
      assert Application.get_env(:logger, :console) != nil
    end

    test "uses Jason for JSON" do
      assert Application.get_env(:phoenix, :json_library) == Jason
    end

    test "has Elm configuration" do
      elm_config = Application.get_env(:web_ui, :elm)

      assert elm_config != nil
      assert elm_config[:elm_path] == "assets/elm"
      assert elm_config[:elm_main] == "Main"
      assert elm_config[:elm_output] == "priv/static/web_ui/assets"
    end

    test "has Tailwind configuration" do
      tailwind_config = Application.get_env(:web_ui, :tailwind)

      assert tailwind_config != nil
      assert tailwind_config[:input] == "assets/css/app.css"
      assert tailwind_config[:output] == "priv/static/web_ui/assets/app.css"
    end

    test "has esbuild configuration" do
      esbuild_config = Application.get_env(:web_ui, :esbuild)

      assert esbuild_config != nil
      assert esbuild_config[:entry] == "assets/js/web_ui_interop.js"
      assert esbuild_config[:output] == "priv/static/web_ui/assets/interop.js"
    end

    test "has static asset configuration" do
      static_config = Application.get_env(:web_ui, :static)

      assert static_config != nil
      assert static_config[:at] == "/"
      assert static_config[:from] == "priv/static"
    end

    test "has WebSocket configuration" do
      ws_config = Application.get_env(:web_ui, :websocket)

      assert ws_config != nil
      assert ws_config[:heartbeat_interval] == 30_000
      assert ws_config[:timeout] == 60_000
    end

    test "has CloudEvents configuration" do
      ce_config = Application.get_env(:web_ui, :cloudevents)

      assert ce_config != nil
      assert ce_config[:specversion] == "1.0"
      assert ce_config[:default_datacontenttype] == "application/json"
    end

    test "has shutdown timeout configuration" do
      timeout = WebUi.Application.shutdown_timeout()

      assert timeout > 0
      assert is_integer(timeout)
    end
  end

  describe "environment-specific configs" do
    test "dev.exs has debug logging enabled" do
      env = Mix.env()

      if env == :dev do
        assert Application.get_env(:logger, :level) == :debug
      end
    end

    test "test.exs disables server" do
      env = Mix.env()

      if env == :test do
        endpoint_config = Application.get_env(:web_ui, WebUi.Endpoint)
        assert endpoint_config[:server] == false
      end
    end
  end

  describe "application startup configuration" do
    test "defaults to library mode" do
      start_config = Application.get_env(:web_ui, :start)

      assert start_config != nil
      # Library mode has empty children list by default
      assert Keyword.get(start_config, :children, []) == []
    end
  end

  describe "graceful shutdown" do
    test "shutdown_timeout is configured" do
      timeout = Application.get_env(:web_ui, :shutdown_timeout)

      assert timeout != nil
      assert timeout > 0
    end
  end
end
