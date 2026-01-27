defmodule WebUi.Router do
  @moduledoc """
  Router for WebUI.

  Defines HTTP routes for serving the Elm SPA and handling API requests.

  ## Usage

  In your application, you can `use WebUi.Router` to get default routes:

      defmodule MyRouter do
        use WebUi.Router

        # Add your custom routes here
      end

  Or import routes into your existing router:

      defmodule MyRouter do
        use Phoenix.Router

        import WebUi.Router.Defaults
      end
  """

  use Phoenix.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", WebUi do
    pipe_through(:browser)

    get("/", PageController, :index)
    get("/health", PageController, :health)
  end

  # scope "/api", WebUi do
  #   pipe_through :api
  # end
end

defmodule WebUi.PageController do
  @moduledoc """
  Controller for serving pages.

  The main controller serves the Elm SPA bootstrap HTML.
  """

  use Phoenix.Controller,
    formats: [html: "View", json: "View"]

  @doc """
  Serves the Elm SPA index page.
  """
  def index(conn, _params) do
    flags = get_server_flags(conn)

    html(conn, """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>WebUI App</title>
        <link rel="stylesheet" href="/assets/app.css"/>
      </head>
      <body>
        <div id="app"></div>
        <script>
          window.wsUrl = "#{flags.ws_url}";
          window.serverFlags = #{Jason.encode!(flags)};
        </script>
        <script src="/assets/interop.js"></script>
        <script src="/assets/app.js"></script>
      </body>
    </html>
    """)
  end

  @doc """
  Health check endpoint.

  Returns 200 OK if the application is running.
  """
  def health(conn, _params) do
    json(conn, %{
      status: "ok",
      version: version()
    })
  end

  defp version do
    Application.spec(:web_ui, :vsn) || "0.1.0"
  end

  defp get_server_flags(conn) do
    %{
      now: System.system_time(:millisecond),
      ws_url: websocket_url(conn),
      user_agent: get_req_header(conn, "user-agent") |> List.first(),
      custom: Application.get_env(:web_ui, :server_flags, %{})
    }
  end

  defp websocket_url(conn) do
    scheme = if conn.scheme == :https, do: "wss", else: "ws"
    "#{scheme}://#{conn.host}:#{conn.port}/socket/websocket"
  end
end
