defmodule WebUi.PageControllerTest do
  @moduledoc """
  Tests for WebUi.PageController.
  """

  use ExUnit.Case, async: true

  import Plug.Conn
  import Phoenix.ConnTest, only: [build_conn: 0]
  import Phoenix.Controller, only: [put_format: 2, put_view: 2]

  alias WebUi.{PageController, PageView}

  setup do
    # Build a basic test connection with view module set
    # Note: We call controller functions directly, so we need to set the view
    conn =
      build_conn()
      |> put_view(PageView)
      |> put_format("html")

    {:ok, conn: conn}
  end

  # Helper to get response body from conn
  defp response_body(%Plug.Conn{resp_body: body}) when is_binary(body), do: body
  defp response_body(%Plug.Conn{}), do: ""

  describe "index/2" do
    test "returns HTML response", %{conn: conn} do
      conn = PageController.index(conn, %{})

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> List.first() =~ "text/html"
    end

    test "includes Elm mount point div", %{conn: conn} do
      conn = PageController.index(conn, %{})
      body = response_body(conn)

      assert body =~ ~s(id="app")
    end

    test "includes WebSocket URL in flags", %{conn: conn} do
      conn = PageController.index(conn, %{})
      body = response_body(conn)

      assert body =~ "window.wsUrl"
      assert body =~ "ws://"
    end

    test "includes server flags", %{conn: conn} do
      conn = PageController.index(conn, %{})
      body = response_body(conn)

      assert body =~ "window.serverFlags"
      assert body =~ "pageLoadedAt"
    end

    test "includes CSS reference", %{conn: conn} do
      conn = PageController.index(conn, %{})
      body = response_body(conn)

      assert body =~ ~s(href="/assets/app.css")
    end

    test "includes JavaScript references", %{conn: conn} do
      conn = PageController.index(conn, %{})
      body = response_body(conn)

      assert body =~ ~s(src="/assets/interop.js")
      assert body =~ ~s(src="/assets/app.js")
    end

    test "sets cache control header", %{conn: conn} do
      conn = PageController.index(conn, %{})

      assert get_resp_header(conn, "cache-control") |> List.first() =~ "no-cache"
    end

    test "includes loading state styles", %{conn: conn} do
      conn = PageController.index(conn, %{})
      body = response_body(conn)

      assert body =~ "loading"
      assert body =~ "animation: spin"
    end

    test "includes viewport meta tag", %{conn: conn} do
      conn = PageController.index(conn, %{})
      body = response_body(conn)

      assert body =~ ~s(name="viewport")
      assert body =~ "width=device-width"
    end

    test "includes nonce for CSP", %{conn: conn} do
      conn = PageController.index(conn, %{})
      body = response_body(conn)

      assert body =~ ~s(nonce=)
    end

    test "renders default title when no metadata", %{conn: conn} do
      conn = PageController.index(conn, %{})
      body = response_body(conn)

      assert body =~ ~s(<title>WebUI</title>)
    end

    test "renders custom title from metadata", %{conn: conn} do
      conn =
        conn
        |> assign(:page_title, "About Us")
        |> PageController.index(%{})

      body = response_body(conn)

      assert body =~ ~s(<title>About Us</title>)
    end

    test "renders custom description from metadata", %{conn: conn} do
      conn =
        conn
        |> assign(:page_description, "Learn about our company")
        |> PageController.index(%{})

      body = response_body(conn)

      assert body =~ ~s(content="Learn about our company")
    end

    test "renders keywords from metadata", %{conn: conn} do
      conn =
        conn
        |> assign(:page_keywords, "elixir, phoenix, web")
        |> PageController.index(%{})

      body = response_body(conn)

      assert body =~ ~s(name="keywords" content="elixir, phoenix, web")
    end

    test "renders author from metadata", %{conn: conn} do
      conn =
        conn
        |> assign(:page_author, "Jane Doe")
        |> PageController.index(%{})

      body = response_body(conn)

      assert body =~ ~s(name="author" content="Jane Doe")
    end

    test "renders og_image from metadata", %{conn: conn} do
      conn =
        conn
        |> assign(:page_og_image, "https://example.com/image.png")
        |> PageController.index(%{})

      body = response_body(conn)

      assert body =~ ~s(property="og:image" content="https://example.com/image.png")
      assert body =~ ~s(name="twitter:card" content="summary_large_image")
    end

    test "includes page metadata in serverFlags", %{conn: conn} do
      conn =
        conn
        |> assign(:page_title, "About Us")
        |> assign(:page_description, "Learn about our company")
        |> PageController.index(%{})

      body = response_body(conn)

      assert body =~ "window.serverFlags.pageMetadata"
      assert body =~ "About Us"
    end

    test "includes user agent in flags when present", %{conn: conn} do
      conn =
        conn
        |> put_req_header("user-agent", "TestAgent/1.0")
        |> PageController.index(%{})

      body = response_body(conn)
      assert body =~ "TestAgent/1.0"
    end

    test "uses correct WebSocket URL based on connection", %{conn: conn} do
      conn = %{conn | scheme: :https, host: "example.com", port: 443}
      conn = PageController.index(conn, %{})
      body = response_body(conn)

      assert body =~ "wss://example.com:443"
    end
  end

  describe "health/2" do
    setup do
      conn = build_conn() |> put_format("json")
      {:ok, conn: conn}
    end

    test "returns JSON response", %{conn: conn} do
      conn = PageController.health(conn, %{})

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> List.first() =~ "application/json"
    end

    test "includes status field", %{conn: conn} do
      conn = PageController.health(conn, %{})
      body = response_body(conn)

      json = Jason.decode!(body)
      assert json["status"] == "ok"
    end

    test "includes version field", %{conn: conn} do
      conn = PageController.health(conn, %{})
      body = response_body(conn)

      json = Jason.decode!(body)
      assert json["version"] != nil
      assert is_binary(json["version"])
    end

    test "includes timestamp field", %{conn: conn} do
      conn = PageController.health(conn, %{})
      body = response_body(conn)

      json = Jason.decode!(body)
      assert json["timestamp"] != nil
      assert is_integer(json["timestamp"])
    end
  end

  describe "error/2" do
    test "renders error page with default values", %{conn: conn} do
      conn = PageController.error(conn)
      body = response_body(conn)

      assert body =~ "An Error Occurred"
      assert body =~ "Something went wrong"
    end

    test "renders error page with custom values", %{conn: conn} do
      conn =
        PageController.error(conn,
          status: 404,
          title: "Not Found",
          message: "The page you requested could not be found."
        )

      assert conn.status == 404
      body = response_body(conn)

      assert body =~ "Not Found"
      assert body =~ "The page you requested could not be found"
    end

    test "error page includes home link", %{conn: conn} do
      conn = PageController.error(conn)
      body = response_body(conn)

      assert body =~ ~s(href="/")
      assert body =~ "Go Home"
    end

    test "error page includes back button", %{conn: conn} do
      conn = PageController.error(conn)
      body = response_body(conn)

      assert body =~ "history.back()"
      assert body =~ "Go Back"
    end

    test "error page shows status code", %{conn: conn} do
      conn = PageController.error(conn, status: 404)
      body = response_body(conn)

      assert body =~ "404"
    end
  end

  describe "version/0" do
    test "returns version string" do
      version = PageController.version()

      assert is_binary(version)
      assert String.length(version) > 0
    end
  end

  describe "custom server flags" do
    setup do
      # Save original config
      original_config = Application.get_env(:web_ui, :server_flags)

      # Set test config
      Application.put_env(:web_ui, :server_flags, %{
        test_flag: "test_value",
        user_id: fn _conn -> "test_user" end
      })

      on_exit(fn ->
        # Restore original config
        if original_config do
          Application.put_env(:web_ui, :server_flags, original_config)
        else
          Application.delete_env(:web_ui, :server_flags)
        end
      end)

      :ok
    end

    test "includes static custom flags", %{conn: conn} do
      conn = PageController.index(conn, %{})
      body = response_body(conn)

      assert body =~ "test_flag"
      assert body =~ "test_value"
    end

    test "evaluates function flags", %{conn: conn} do
      conn = PageController.index(conn, %{})
      body = response_body(conn)

      assert body =~ "user_id"
      assert body =~ "test_user"
    end
  end

  describe "WebSocket URL generation" do
    test "uses ws:// for http connections", %{conn: conn} do
      conn = %{conn | scheme: :http, host: "localhost", port: 4000}
      conn = PageController.index(conn, %{})
      body = response_body(conn)

      assert body =~ "ws://localhost:4000"
    end

    test "uses wss:// for https connections", %{conn: conn} do
      conn = %{conn | scheme: :https, host: "example.com", port: 443}
      conn = PageController.index(conn, %{})
      body = response_body(conn)

      assert body =~ "wss://example.com:443"
    end

    test "uses custom websocket path from config", %{conn: conn} do
      Application.put_env(:web_ui, WebUi.PageController, websocket_path: "/custom/socket")

      on_exit(fn ->
        Application.delete_env(:web_ui, WebUi.PageController)
      end)

      conn = PageController.index(conn, %{})
      body = response_body(conn)

      assert body =~ "/custom/socket"
    end
  end
end
