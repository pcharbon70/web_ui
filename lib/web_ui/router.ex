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

  ## Routes

  The following routes are defined by default:

  | Route | Handler | Purpose |
  |-------|---------|---------|
  | GET / | PageController.index | Serves Elm SPA |
  | GET /health | PageController.health | Health check endpoint |

  ## Adding Custom Routes

  You can extend the router in your application:

      defmodule MyRouter do
        use WebUi.Router

        scope "/api", WebUi do
          pipe_through :api

          resources "/posts", PostController
        end
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

  # Uncomment and customize for API routes:
  # scope "/api", WebUi do
  #   pipe_through :api
  #
  #   # Add your API routes here
  # end
end
