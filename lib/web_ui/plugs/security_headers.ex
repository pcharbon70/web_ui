defmodule WebUi.Plugs.SecurityHeaders do
  @moduledoc """
  Plug for adding security headers to all responses.

  This plug adds important security headers to help protect against
  common web vulnerabilities including XSS, clickjacking, and other
  attacks.

  ## Security Headers Added

  * `X-Frame-Options` - Prevents clickjacking attacks
  * `X-Content-Type-Options` - Prevents MIME sniffing
  * `X-XSS-Protection` - Enables XSS filtering in browsers
  * `Content-Security-Policy` - Controls resource loading
  * `Referrer-Policy` - Controls referrer information
  * `Permissions-Policy` - Controls browser features

  ## Configuration

  Configure security headers in your `config/config.exs`:

      config :web_ui, WebUi.Plugs.SecurityHeaders,
        # Content-Security-Policy (default: restrictive)
        csp: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'",
        # X-Frame-Options (default: "SAMEORIGIN")
        frame_options: "SAMEORIGIN",
        # Referrer-Policy (default: "strict-origin-when-cross-origin")
        referrer_policy: "strict-origin-when-cross-origin",
        # Enable Permissions-Policy (default: true)
        enable_permissions_policy: true,
        # Enable X-XSS-Protection (default: true, deprecated but still useful)
        enable_xss_protection: true

  For development, you may want to relax some restrictions:

      config :dev, :web_ui, WebUi.Plugs.SecurityHeaders,
        csp: "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob:"

  ## Examples

      plug WebUi.Plugs.SecurityHeaders

  Or with custom options:

      plug WebUi.Plugs.SecurityHeaders,
        csp: "default-src 'self'",
        frame_options: "DENY"

  """
  import Plug.Conn

  @type options :: [
    csp: String.t() | nil,
    frame_options: String.t(),
    referrer_policy: String.t(),
    enable_permissions_policy: boolean(),
    enable_xss_protection: boolean()
  ]

  @doc """
  Initializes the plug with options.

  Options can be provided at compile time or configured via Application
  configuration for runtime flexibility.
  """
  @spec init(keyword()) :: keyword()
  def init(opts \\ []) do
    # Get app config for defaults
    app_config = Application.get_env(:web_ui, __MODULE__, [])

    [
      csp: Keyword.get(opts, :csp, Keyword.get(app_config, :csp, default_csp())),
      frame_options:
        Keyword.get(opts, :frame_options, Keyword.get(app_config, :frame_options, "SAMEORIGIN")),
      referrer_policy:
        Keyword.get(
          opts,
          :referrer_policy,
          Keyword.get(app_config, :referrer_policy, "strict-origin-when-cross-origin")
        ),
      enable_permissions_policy:
        Keyword.get(
          opts,
          :enable_permissions_policy,
          Keyword.get(app_config, :enable_permissions_policy, true)
        ),
      enable_xss_protection:
        Keyword.get(
          opts,
          :enable_xss_protection,
          Keyword.get(app_config, :enable_xss_protection, true)
        )
    ]
  end

  @doc """
  Calls the plug, adding all security headers to the connection.
  """
  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(%Plug.Conn{} = conn, opts) do
    conn
    |> put_frame_options(Keyword.get(opts, :frame_options))
    |> put_content_type_options()
    |> put_xss_protection(Keyword.get(opts, :enable_xss_protection))
    |> put_csp(Keyword.get(opts, :csp))
    |> put_referrer_policy(Keyword.get(opts, :referrer_policy))
    |> put_permissions_policy(Keyword.get(opts, :enable_permissions_policy))
  end

  # Private helpers

  defp put_frame_options(conn, value) when is_binary(value) do
    put_resp_header(conn, "x-frame-options", value)
  end

  defp put_content_type_options(conn) do
    put_resp_header(conn, "x-content-type-options", "nosniff")
  end

  defp put_xss_protection(conn, true) do
    put_resp_header(conn, "x-xss-protection", "1; mode=block")
  end

  defp put_xss_protection(conn, false), do: conn

  defp put_csp(conn, nil), do: conn
  defp put_csp(conn, csp) when is_binary(csp), do: put_resp_header(conn, "content-security-policy", csp)

  defp put_referrer_policy(conn, value) when is_binary(value) do
    put_resp_header(conn, "referrer-policy", value)
  end

  defp put_permissions_policy(conn, true) do
    put_resp_header(
      conn,
      "permissions-policy",
      "geolocation=(), microphone=(), camera=(), payment=(), usb=()"
    )
  end

  defp put_permissions_policy(conn, false), do: conn

  # Default CSP for Elm SPA
  # Allows same-origin by default, inline scripts/styles for Elm
  defp default_csp do
    case Mix.env() do
      :dev ->
        # More permissive for development
        "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob: ws://localhost:* wss://localhost:*; connect-src 'self' ws://localhost:* wss://localhost:;"

      _ ->
        # Stricter for production
        "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self' ws: wss:; manifest-src 'self'"
    end
  end
end
