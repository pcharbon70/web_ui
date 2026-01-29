# Authentication Guide

WebUI is designed as a library that can be integrated into your application. Authentication patterns are implemented at the application level, allowing flexibility in choosing your authentication strategy.

## Table of Contents

1. [Overview](#overview)
2. [Session Authentication](#session-authentication)
3. [WebSocket Authentication](#websocket-authentication)
4. [Channel Authorization](#channel-authorization)
5. [Example Implementations](#example-implementations)
6. [Security Best Practices](#security-best-practices)

---

## Overview

WebUI provides hooks for authentication but doesn't enforce a specific authentication strategy. This allows you to integrate with:

- Session-based authentication (cookies)
- Token-based authentication (JWT, API keys)
- OAuth/OIDC providers
- Custom authentication schemes

### Authentication Points

1. **HTTP Requests** - Via Plug session middleware
2. **WebSocket Connections** - Via UserSocket connect callback
3. **Channel Joins** - Via EventChannel authorization callback

---

## Session Authentication

### Setting Up User Sessions

WebUI uses Phoenix's session infrastructure. To add authentication:

```elixir
# In your application's router or endpoint

defmodule MyApp.Web do
  def controller do
    quote do
      use Phoenix.Controller,
        layouts: [html: MyApp.Layouts]

      import Plug.Conn
      import MyApp.Authentication

      # Add current_user to assigns
      def action(conn, _opts) do
        user = get_current_user(conn)
        assign(conn, :current_user, user)
      end
    end
  end
end
```

### Authentication Module

```elixir
defmodule MyApp.Authentication do
  import Plug.Conn

  @session_key "user_id"

  @doc "Get the current user from session"
  def get_current_user(conn) do
    with user_id when not is_nil(user_id) <- get_session(conn, @session_key),
         user when not is_nil(user) <- MyApp.Accounts.get_user(user_id) do
      user
    else
      _ -> nil
    end
  end

  @doc "Log in a user"
  def login_user(conn, user) do
    conn
    |> put_session(@session_key, user.id)
    |> configure_session(renew: true)
  end

  @doc "Log out the current user"
  def logout_user(conn) do
    configure_session(conn, drop: true)
  end

  @doc "Require authentication for a route"
  def require_user(conn, _opts) do
    if get_session(conn, @session_key) do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page")
      |> redirect(to: "/login")
      |> halt()
    end
  end
end
```

### Using Authentication in Routes

```elixir
defmodule MyApp.Router do
  use WebUi.Router

  import MyApp.Authentication

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:put_user_assigns)  # Custom plug
  end

  pipeline :authenticated do
    plug(:require_user)
  end

  scope "/", MyApp do
    pipe_through([:browser])

    get "/login", SessionController, :new
    post "/login", SessionController, :create
  end

  scope "/", MyApp do
    pipe_through([:browser, :authenticated])

    # Protected routes here
  end
end
```

---

## WebSocket Authentication

### Authenticating WebSocket Connections

WebSocket authentication happens in the `connect/3` callback of UserSocket. You can override this in your application:

```elixir
# In your application, override the socket connection

defmodule MyApp.Web do
  def socket do
    quote do
      # Use WebUI.UserSocket but override connect
      defmodule WebUi.UserSocket do
        use Phoenix.Socket

        @impl true
        def connect(params, socket, connect_info) do
          # Get token from params or session
          token = Map.get(params, "token")
          origin_check = check_origin(connect_info)

          with true <- origin_check == :ok,
               {:ok, user_id} <- verify_token(token) do
            socket = assign(socket, :user_id, user_id)
            {:ok, socket}
          else
            _ -> :error
          end
        end

        @impl true
        def id(socket), do: "user:#{socket.assigns.user_id}"

        # Keep original channel definitions
        channel("events:*", WebUi.EventChannel)

        # Import helper functions from WebUi
        import WebUi.UserSocket
      end
    end
  end
end
```

### Token-Based Authentication

```elixir
defmodule MyApp.Authentication do
  @doc "Verify an authentication token"
  def verify_token(token) do
    # Implement your token verification
    # This could be JWT, API key, etc.

    case MyApp.Token.verify_and_validate(token) do
      {:ok, claims} -> {:ok, claims["user_id"]}
      _error -> :error
    end
  end

  @doc "Generate an authentication token"
  def generate_token(user) do
    MyApp.Token.generate_and_sign!(%{user_id: user.id})
  end
end
```

---

## Channel Authorization

### Configure Authorization Callback

WebUI's EventChannel supports an authorization callback:

```elixir
# config/config.exs

config :web_ui, WebUi.EventChannel,
  authorize_join: {MyApp.Authorization, :authorize_channel_join}
```

### Implement Authorization Module

```elixir
defmodule MyApp.Authorization do
  @doc """
  Authorize a channel join request.

  Returns {:ok, socket} or {:error, reason}.
  """
  def authorize_channel_join("events:lobby", _payload, socket) do
    # Public lobby - allow all
    {:ok, socket}
  end

  def authorize_channel_join("events:" <> room_id, payload, socket) do
    # Private room - check permissions
    user_id = socket.assigns[:user_id]
    room_permissions = MyApp.Permissions.room_permissions(user_id, room_id)

    if can_join_room?(room_permissions) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def authorize_channel_join(_topic, _payload, _socket) do
    {:error, %{reason: "invalid_topic"}}
  end

  defp can_join_room?(permissions), do: permissions[:join] == true
end
```

### Passing User Context to Channels

```elixir
# In your custom socket connect function
def connect(params, socket, _connect_info) do
  case authenticate(params) do
    {:ok, user} ->
      socket =
        socket
        |> assign(:user_id, user.id)
        |> assign(:user_role, user.role)
        |> assign(:permissions, user.permissions)

      {:ok, socket}

    :error ->
      :error
  end
end
```

---

## Example Implementations

### Using Guardian

```elixir
# mix.exs
defp deps do
  [
    {:guardian, "~> 2.3"}
  ]
end

# lib/my_app/guardian.ex
defmodule MyApp.Guardian do
  use Guardian, otp_app: :my_app

  def subject_for_token(%{id: id}, _claims), do: {:ok, to_string(id)}
  def resource_from_claims(%{"sub" => id}), do: {:ok, MyApp.Accounts.get_user(id)}

  def build_claims(claims, resource, _opts) do
    claims = claims
      |> Map.put("role", resource.role)
      |> Map.put("permissions", resource.permissions)

    {:ok, claims}
  end
end

# lib/my_app/authentication.ex
defmodule MyApp.Authentication do
  import Plug.Conn

  def login(conn, user) do
    conn
    |> MyApp.Guardian.Plug.sign_in(user)
    |> put_session(:user_id, user.id)
  end

  def logout(conn) do
    conn
    |> MyApp.Guardian.Plug.sign_out()
    |> configure_session(drop: true)
  end
end

# WebSocket with Guardian
def connect(%{"token" => token}, socket) do
  case MyApp.Guardian.resource_from_token(token) do
    {:ok, user, _claims} ->
      {:ok, assign(socket, :current_user, user)}

    _error ->
      :error
  end
end
```

### Using OAuth/OIDC

```elixir
# lib/my_app/oauth.ex
defmodule MyApp.OAuth do
  @callback get_user_info(token :: String.t()) :: {:ok, map()} | {:error, term()}

  def get_user_info(provider, token) do
    # Implement OAuth user info retrieval
    # for providers like Google, GitHub, Auth0, etc.
  end

  def create_or_update_user(provider, user_info) do
    # Create or update user from OAuth provider info
  end
end

# Controller handling OAuth callback
defmodule MyApp.OAuthController do
  use MyApp.Web, :controller

  def callback(conn, %{"provider" => provider, "code" => code}) do
    with {:ok, token} <- get_access_token(provider, code),
         {:ok, user_info} <- MyApp.OAuth.get_user_info(provider, token),
         {:ok, user} <- MyApp.OAuth.create_or_update_user(provider, user_info) do
      conn
      |> put_flash(:info, "Welcome!")
      |> MyApp.Authentication.login(user)
      |> redirect(to: "/")
    else
      _error ->
        conn
        |> put_flash(:error, "Authentication failed")
        |> redirect(to: "/login")
    end
  end
end
```

---

## Security Best Practices

### 1. Always Use HTTPS in Production

```elixir
# config/prod.exs
config :web_ui, WebUi.Endpoint,
  force_ssl: [hsts: true]
```

### 2. Set Secure Cookie Flags

```elixir
config :web_ui, WebUi.Endpoint,
  session_options: [
    secure: true,      # Only send over HTTPS
    http_only: true,   # Not accessible via JavaScript
    same_site: "Lax"   # CSRF protection
  ]
```

### 3. Implement Rate Limiting

```elixir
# Rate limit login attempts
defmodule MyApp.LoginRateLimit do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()

    case check_rate_limit(ip) do
      :ok -> conn
      :rate_limited ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(429, Jason.encode!(%{error: "Too many attempts"}))
        |> halt()
    end
  end

  defp check_rate_limit(ip) do
    # Implement rate limiting logic
    # Using ETS, Redis, or another store
  end
end
```

### 4. Validate Session Data

```elixir
def get_current_user(conn) do
  case get_session(conn, :user_id) do
    nil -> nil
    user_id ->
      case MyApp.Accounts.get_user(user_id) do
        {:ok, user} -> user
        {:error, :not_found} ->
          # Clear invalid session
          configure_session(conn, drop: true)
          nil
      end
  end
end
```

### 5. Implement CSRF Protection

WebUI enables CSRF protection by default. Ensure your forms include the CSRF token:

```elixir
# In your layout or view
<%= csrf_meta_tag() %>
```

Or for API requests:

```javascript
// Include CSRF token in headers
const csrfToken = document.querySelector('meta[name="csrf-token"]').content;
fetch('/api/endpoint', {
  headers: {
    'X-CSRF-Token': csrfToken
  }
});
```

### 6. Log Security Events

```elixir
defmodule MyApp.SecurityAudit do
  require Logger

  def log_login_success(user, conn) do
    Logger.info("User login success",
      user_id: user.id,
      ip: inspect(conn.remote_ip),
      user_agent: get_req_header(conn, "user-agent")
    )
  end

  def log_login_failure(identifier, conn) do
    Logger.warning("User login failure",
      identifier: identifier,
      ip: inspect(conn.remote_ip),
      user_agent: get_req_header(conn, "user-agent")
    )
  end
end
```

---

## Testing Authentication

### Unit Tests

```elixir
defmodule MyApp.AuthenticationTest do
  use ExUnit.Case

  test "login_user/2 sets user in session" do
    conn = build_conn()
    user = insert(:user)

    conn = MyApp.Authentication.login_user(conn, user)

    assert get_session(conn, "user_id") == user.id
  end

  test "require_user/2 redirects when not authenticated" do
    conn = build_conn()
    conn = MyApp.Authentication.require_user(conn, [])

    assert redirected_to(conn) == "/login"
  end
end
```

### Integration Tests

```elixir
defmodule MyApp.Web.AuthTest do
  use MyApp.Web.ConnCase

  test "protected routes require authentication" do
    conn = get(build_conn(), "/dashboard")

    assert redirected_to(conn) == "/login"
  end

  test "authenticated users can access protected routes" do
    user = insert(:user)
    conn = login_user(build_conn(), user)
    conn = get(conn, "/dashboard")

    assert html_response(conn, 200)
  end
end
```

---

## Additional Resources

- [Phoenix Authentication Guide](https://hexdocs.pm/phoenix/authentication.html)
- [Guardian Documentation](https://hexdocs.pm/guardian/readme.html)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [OWASP Session Management](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)
