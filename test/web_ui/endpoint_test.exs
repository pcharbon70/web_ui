defmodule WebUi.EndpointTest do
  @moduledoc """
  Tests for WebUi.Endpoint configuration.
  """

  use ExUnit.Case, async: true

  describe "endpoint configuration" do
    test "websocket_timeout returns configured value" do
      timeout = WebUi.Endpoint.websocket_timeout()
      assert is_integer(timeout)
      assert timeout > 0
    end

    test "websocket timeout has environment-specific defaults" do
      timeout = WebUi.Endpoint.websocket_timeout()
      assert timeout == 5000
    end
  end

  describe "static asset configuration" do
    test "gzip is disabled in test environment" do
      endpoint_config = Application.get_env(:web_ui, WebUi.Endpoint, [])
      gzip = Keyword.get(endpoint_config, :gzip_static)
      refute gzip
    end
  end

  describe "WebSocket origin checking" do
    test "allows localhost in test environment" do
      origin = "http://localhost:4000"
      uri = URI.parse(origin)
      assert uri.host == "localhost"
      assert uri.port == 4000
    end

    test "allows 127.0.0.1 in test environment" do
      origin = "http://127.0.0.1:4000"
      uri = URI.parse(origin)
      assert uri.host == "127.0.0.1"
      assert uri.port == 4000
    end

    test "rejects non-localhost origins" do
      origin = "http://evil.com"
      uri = URI.parse(origin)
      assert uri.host == "evil.com"
      refute uri.host in ["localhost", "127.0.0.1"]
    end
  end
end

defmodule WebUi.SecurityHeadersTest do
  @moduledoc """
  Tests for WebUi.Plugs.SecurityHeaders.
  """

  use ExUnit.Case, async: true
  import Plug.Test

  alias WebUi.Plugs.SecurityHeaders

  describe "init/1" do
    test "returns options with defaults" do
      opts = SecurityHeaders.init([])
      assert Keyword.has_key?(opts, :csp)
      assert Keyword.has_key?(opts, :frame_options)
      assert Keyword.has_key?(opts, :referrer_policy)
    end

    test "merges user options with defaults" do
      opts = SecurityHeaders.init(frame_options: "DENY")
      assert Keyword.get(opts, :frame_options) == "DENY"
    end
  end

  describe "call/2" do
    test "adds x-frame-options header" do
      conn = conn(:get, "/")
      opts = SecurityHeaders.init([])

      conn = SecurityHeaders.call(conn, opts)

      assert {"x-frame-options", "SAMEORIGIN"} in conn.resp_headers
    end

    test "adds x-content-type-options header" do
      conn = conn(:get, "/")
      opts = SecurityHeaders.init([])

      conn = SecurityHeaders.call(conn, opts)

      assert {"x-content-type-options", "nosniff"} in conn.resp_headers
    end

    test "adds referrer-policy header" do
      conn = conn(:get, "/")
      opts = SecurityHeaders.init([])

      conn = SecurityHeaders.call(conn, opts)

      assert {"referrer-policy", _} = Enum.find(conn.resp_headers, fn {k, _} -> k == "referrer-policy" end)
    end

    test "adds content-security-policy header when configured" do
      conn = conn(:get, "/")
      opts = SecurityHeaders.init(csp: "default-src 'self'")

      conn = SecurityHeaders.call(conn, opts)

      assert {"content-security-policy", "default-src 'self'"} in conn.resp_headers
    end

    test "does not add csp when nil" do
      conn = conn(:get, "/")
      opts = SecurityHeaders.init(csp: nil)

      conn = SecurityHeaders.call(conn, opts)

      refute Enum.any?(conn.resp_headers, fn {k, _} -> k == "content-security-policy" end)
    end

    test "adds permissions-policy when enabled" do
      conn = conn(:get, "/")
      opts = SecurityHeaders.init(enable_permissions_policy: true)

      conn = SecurityHeaders.call(conn, opts)

      assert {"permissions-policy", _} = Enum.find(conn.resp_headers, fn {k, _} -> k == "permissions-policy" end)
    end

    test "does not add permissions-policy when disabled" do
      conn = conn(:get, "/")
      opts = SecurityHeaders.init(enable_permissions_policy: false)

      conn = SecurityHeaders.call(conn, opts)

      refute Enum.any?(conn.resp_headers, fn {k, _} -> k == "permissions-policy" end)
    end

    test "adds x-xss-protection when enabled" do
      conn = conn(:get, "/")
      opts = SecurityHeaders.init(enable_xss_protection: true)

      conn = SecurityHeaders.call(conn, opts)

      assert {"x-xss-protection", "1; mode=block"} in conn.resp_headers
    end

    test "does not add x-xss-protection when disabled" do
      conn = conn(:get, "/")
      opts = SecurityHeaders.init(enable_xss_protection: false)

      conn = SecurityHeaders.call(conn, opts)

      refute Enum.any?(conn.resp_headers, fn {k, _} -> k == "x-xss-protection" end)
    end
  end
end
