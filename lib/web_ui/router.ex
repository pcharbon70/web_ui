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
  | GET /*path | PageController.index | SPA catch-all for client routing |

  ## defpage Macro

  The `defpage/2` macro provides a convenient way to define Elm page routes
  with metadata:

      defpage "/about", title: "About Us", description: "Learn about our company"
      defpage "/contact", title: "Contact"
      defpage "/products/:id", title: "Product Details"

  The metadata is passed as assigns to the controller:
  * `@page_title` - Available in templates
  * `@page_description` - Meta description for SEO
  * `@page_keywords` - Meta keywords
  * `@page_author` - Meta author
  * `@page_og_image` - Open Graph image URL

  ## Adding Custom Routes

  You can extend the router in your application:

      defmodule MyRouter do
        use WebUi.Router

        scope "/api", WebUi do
          pipe_through :api

          resources "/posts", PostController
        end
      end

  ## Configuration

  Configure the router behavior:

      config :web_ui, WebUi.Router,
        enable_catch_all: true,
        spa_index: "/"

  """

  use Phoenix.Router

  alias Phoenix.Router.Scope
  alias WebUi.Plugs.{PageMetadata, SecurityHeaders}

  # Module attributes for configuration
  @enable_catch_all Application.compile_env(:web_ui, WebUi.Router, [])
                    |> Keyword.get(:enable_catch_all, true)

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(SecurityHeaders)
    plug(PageMetadata)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(SecurityHeaders)
  end

  scope "/", WebUi do
    pipe_through(:browser)

    Phoenix.Router.get("/", PageController, :index)
    Phoenix.Router.get("/health", PageController, :health)
  end

  # Catch-all route for SPA client-side routing
  # This must be last as it matches all paths
  if @enable_catch_all do
    scope "/", WebUi do
      pipe_through(:browser)

      # Match any path for client-side routing in Elm
      Phoenix.Router.get("/*path", PageController, :index)
    end
  end

  @doc """
  Callback for `use WebUi.Router`.

  Sets up Phoenix.Router with all its standard imports and adds
  the defpage and pages macros for convenient SPA route definition.

  ## Example

      defmodule MyRouter do
        use WebUi.Router

        pipeline :browser do
          plug(:accepts, ["html"])
        end

        scope "/", WebUi do
          pipe_through(:browser)

          defpage "/about", title: "About Us"
        end
      end

  """
  defmacro __using__(opts) do
    quote do
      # Import Phoenix.Router first - this gives us pipeline, scope, get, post, etc.
      import Phoenix.Router

      # Import Plug.Conn and Phoenix.Controller (same as Phoenix.Router does)
      import Plug.Conn
      import Phoenix.Controller

      # Register module attributes for Phoenix.Router
      Module.register_attribute(__MODULE__, :phoenix_routes, accumulate: true)
      @phoenix_helpers Keyword.get(unquote(opts), :helpers, true)

      # Set up initial scope and before_compile hook
      @phoenix_pipeline nil
      Scope.init(__MODULE__)
      @before_compile Phoenix.Router

      # Import defpage and pages macros from WebUi.Router
      # We import after Phoenix.Router setup to avoid conflicts
      import WebUi.Router, only: [defpage: 2, pages: 1]
    end
  end

  @doc """
  Defines a page route for the Elm SPA.

  This macro generates a route that serves the SPA with additional
  page-specific metadata passed as assigns.

  ## Options

    * `:title` - Page title for SEO
    * `:description` - Page description for SEO
    * `:keywords` - Page keywords for SEO
    * `:author` - Page author metadata
    * `:og_image` - Open Graph image URL

  ## Examples

      defpage "/about", title: "About Us", description: "Learn about our company"
      defpage "/contact", title: "Contact Us"
      defpage "/products/:id", title: "Product Details"

  The metadata is made available as assigns in the controller and views:
  * `@page_title` - Page title
  * `@page_description` - Meta description
  * `@page_keywords` - Meta keywords
  * `@page_author` - Meta author
  * `@page_og_image` - Open Graph image

  """
  defmacro defpage(path, opts \\ []) do
    quote do
      get(
        unquote(path),
        PageController,
        :index,
        metadata: %{page_metadata: unquote(Macro.escape(opts))},
        assigns: %{page_metadata: unquote(Macro.escape(opts))}
      )
    end
  end

  @doc """
  Generates routes for a list of pages.

  ## Examples

      pages([
        {"/about", [title: "About"]},
        {"/contact", [title: "Contact", description: "Get in touch"]}
      ])

  Each page's metadata is passed as assigns to the controller.

  """
  defmacro pages(routes) do
    quote bind_quoted: [routes: routes] do
      for {path, opts} <- routes do
        get(
          path,
          PageController,
          :index,
          metadata: %{page_metadata: opts},
          assigns: %{page_metadata: opts}
        )
      end
    end
  end
end
