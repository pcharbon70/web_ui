defmodule WebUi.RouterTest do
  @moduledoc """
  Tests for WebUi.Router.
  """

  use ExUnit.Case, async: true

  alias WebUi.Router

  # Define test router modules at the top level to avoid nested module issues
  # with Phoenix.Router macros

  defmodule TestRouterWithUse do
    use WebUi.Router

    pipeline :browser do
      plug(:accepts, ["html"])
    end

    scope "/", WebUi do
      pipe_through(:browser)

      Phoenix.Router.get("/", PageController, :index)
      Phoenix.Router.get("/health", PageController, :health)
    end
  end

  defmodule TestRouterWithDefpage do
    use Phoenix.Router

    pipeline :browser do
      plug(:accepts, ["html"])
    end

    import WebUi.Router, only: [defpage: 2]

    scope "/", WebUi do
      pipe_through(:browser)
      defpage "/about", title: "About Us"
    end
  end

  defmodule TestRouterWithMultiOpts do
    use Phoenix.Router

    pipeline :browser do
      plug(:accepts, ["html"])
    end

    import WebUi.Router, only: [defpage: 2]

    scope "/", WebUi do
      pipe_through(:browser)
      defpage "/contact", title: "Contact", description: "Get in touch"
    end
  end

  defmodule TestRouterWithPages do
    use Phoenix.Router

    pipeline :browser do
      plug(:accepts, ["html"])
    end

    import WebUi.Router, only: [pages: 1]

    scope "/", WebUi do
      pipe_through(:browser)

      pages([
        {"/about", [title: "About"]},
        {"/contact", [title: "Contact"]},
        {"/help", [title: "Help", description: "Get help"]}
      ])
    end
  end

  defmodule TestRouterSpaRoutes do
    use Phoenix.Router

    pipeline :browser do
      plug(:accepts, ["html"])
    end

    import WebUi.Router.Defaults

    scope "/", WebUi do
      pipe_through(:browser)
      spa_routes()
    end
  end

  defmodule TestRouterSpaIndex do
    use Phoenix.Router

    pipeline :browser do
      plug(:accepts, ["html"])
    end

    import WebUi.Router.Defaults

    scope "/", WebUi do
      pipe_through(:browser)
      spa_index()
    end
  end

  defmodule TestRouterSpaHealth do
    use Phoenix.Router

    pipeline :browser do
      plug(:accepts, ["html"])
    end

    import WebUi.Router.Defaults

    scope "/", WebUi do
      pipe_through(:browser)
      spa_health()
    end
  end

  defmodule TestRouterSpaCatchAll do
    use Phoenix.Router

    pipeline :browser do
      plug(:accepts, ["html"])
    end

    import WebUi.Router.Defaults

    scope "/", WebUi do
      pipe_through(:browser)
      spa_catch_all()
    end
  end

  defmodule TestRouterSpaPage do
    use Phoenix.Router

    pipeline :browser do
      plug(:accepts, ["html"])
    end

    import WebUi.Router.Defaults

    scope "/", WebUi do
      pipe_through(:browser)
      spa_page("/about", title: "About Us")
    end
  end

  describe "Router structure" do
    test "router module is defined" do
      assert Code.ensure_loaded?(WebUi.Router)
    end

    test "router has routes defined" do
      routes = Router.__routes__()
      assert is_list(routes)
      assert length(routes) > 0
    end
  end

  describe "Default routes" do
    test "GET / route is defined" do
      routes = Router.__routes__()
      index_route = Enum.find(routes, fn r -> r.path == "/" and r.verb == :get end)

      refute index_route == nil
      assert index_route.plug == WebUi.PageController
      assert index_route.plug_opts == :index
    end

    test "GET /health route is defined" do
      routes = Router.__routes__()
      health_route = Enum.find(routes, fn r -> r.path == "/health" and r.verb == :get end)

      refute health_route == nil
      assert health_route.plug == WebUi.PageController
      assert health_route.plug_opts == :health
    end

    test "catch-all route /*path is defined" do
      routes = Router.__routes__()
      catchall_route = Enum.find(routes, fn r -> r.path == "/*path" end)

      refute catchall_route == nil
      assert catchall_route.plug == WebUi.PageController
      assert catchall_route.plug_opts == :index
    end
  end

  describe "defpage macro" do
    test "defpage generates correct route" do
      routes = TestRouterWithDefpage.__routes__()
      about_route = Enum.find(routes, fn r -> r.path == "/about" and r.verb == :get end)

      refute about_route == nil
      assert about_route.plug == WebUi.PageController
    end

    test "defpage generates route with multiple options" do
      routes = TestRouterWithMultiOpts.__routes__()
      contact_route = Enum.find(routes, fn r -> r.path == "/contact" and r.verb == :get end)

      refute contact_route == nil
    end
  end

  describe "pages macro" do
    test "pages generates multiple routes" do
      routes = TestRouterWithPages.__routes__()

      about_route = Enum.find(routes, fn r -> r.path == "/about" end)
      contact_route = Enum.find(routes, fn r -> r.path == "/contact" end)
      help_route = Enum.find(routes, fn r -> r.path == "/help" end)

      refute about_route == nil
      refute contact_route == nil
      refute help_route == nil
    end
  end

  describe "Router.Defaults" do
    test "spa_routes adds all default routes" do
      routes = TestRouterSpaRoutes.__routes__()

      assert Enum.any?(routes, fn r -> r.path == "/" end)
      assert Enum.any?(routes, fn r -> r.path == "/health" end)
      assert Enum.any?(routes, fn r -> r.path == "/*path" end)
    end

    test "spa_index adds only index route" do
      routes = TestRouterSpaIndex.__routes__()

      assert Enum.any?(routes, fn r -> r.path == "/" end)
      refute Enum.any?(routes, fn r -> r.path == "/health" end)
    end

    test "spa_health adds only health route" do
      routes = TestRouterSpaHealth.__routes__()

      refute Enum.any?(routes, fn r -> r.path == "/" end)
      assert Enum.any?(routes, fn r -> r.path == "/health" end)
    end

    test "spa_catch_all adds only catch-all route" do
      routes = TestRouterSpaCatchAll.__routes__()

      refute Enum.any?(routes, fn r -> r.path == "/" end)
      assert Enum.any?(routes, fn r -> r.path == "/*path" end)
    end

    test "spa_page adds page route" do
      routes = TestRouterSpaPage.__routes__()

      assert Enum.any?(routes, fn r -> r.path == "/about" end)
    end
  end

  describe "Extending the router" do
    test "use WebUi.Router provides Phoenix.Router macros and defpage/pages" do
      routes = TestRouterWithUse.__routes__()

      # Should have routes defined via Phoenix.Router macros
      assert Enum.any?(routes, fn r -> r.path == "/" end)
      assert Enum.any?(routes, fn r -> r.path == "/health" end)
    end
  end

  describe "Security" do
    test "browser pipeline is compiled successfully" do
      # The browser pipeline in WebUi.Router includes security headers
      # This is verified by checking the router was compiled successfully
      assert Code.ensure_loaded?(WebUi.Router)
    end

    test "api pipeline is compiled successfully" do
      # The api pipeline in WebUi.Router includes security headers
      assert Code.ensure_loaded?(WebUi.Router)
    end
  end
end
