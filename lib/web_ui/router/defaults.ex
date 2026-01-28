defmodule WebUi.Router.Defaults do
  @moduledoc """
  Default route definitions for WebUI.

  This module provides helper macros and functions that can be imported
  into existing Phoenix routers to add WebUI routes.

  ## Usage

  Import into your existing router:

      defmodule MyRouter do
        use Phoenix.Router

        import WebUi.Router.Defaults

        # Your custom routes here
      end

  ## Available Macros

  * `spa_routes/0` - Adds all default SPA routes
  * `spa_health/0` - Adds only the health check route
  * `spa_catch_all/0` - Adds the catch-all route for client-side routing

  ## Example

      defmodule MyRouter do
        use Phoenix.Router

        pipeline :browser do
          plug(:accepts, ["html"])
          plug(:fetch_session)
          plug(:protect_from_forgery)
        end

        scope "/", WebUi do
          pipe_through(:browser)

          # Import WebUI routes
          spa_routes()
        end
      end
  """

  @doc """
  Adds all default SPA routes to the current scope.

  This includes:
  - GET / for serving the SPA
  - GET /health for health checks
  - GET /*path for catch-all SPA routing

  ## Example

      scope "/", WebUi do
        pipe_through(:browser)
        spa_routes()
      end
  """
  defmacro spa_routes do
    quote do
      Phoenix.Router.get("/", PageController, :index)
      Phoenix.Router.get("/health", PageController, :health)
      Phoenix.Router.get("/*path", PageController, :index)
    end
  end

  @doc """
  Adds only the main SPA index route.

  ## Example

      scope "/", WebUi do
        pipe_through(:browser)
        spa_index()
      end
  """
  defmacro spa_index do
    quote do
      Phoenix.Router.get("/", PageController, :index)
    end
  end

  @doc """
  Adds only the health check route.

  ## Example

      scope "/", WebUi do
        pipe_through(:browser)
        spa_health()
      end
  """
  defmacro spa_health do
    quote do
      Phoenix.Router.get("/health", PageController, :health)
    end
  end

  @doc """
  Adds the catch-all route for SPA client-side routing.

  This should be placed last in your routes as it matches all paths.

  ## Example

      scope "/", WebUi do
        pipe_through(:browser)

        Phoenix.Router.get("/custom", SomeController, :action)
        spa_catch_all()  # Must be last
      end
  """
  defmacro spa_catch_all do
    quote do
      Phoenix.Router.get("/*path", PageController, :index)
    end
  end

  @doc """
  Adds a page route for the SPA.

  ## Example

      scope "/", WebUi do
        pipe_through(:browser)

        spa_page("/about", title: "About Us")
        spa_page("/contact", title: "Contact", description: "Get in touch")
      end
  """
  defmacro spa_page(path, _opts \\ []) do
    quote do
      Phoenix.Router.get(unquote(path), PageController, :index)
    end
  end
end
