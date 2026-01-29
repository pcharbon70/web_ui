import Config

# Session Security - REQUIRED for production
# These environment variables MUST be set in production
config :web_ui,
       :session_key,
       System.get_env("WEB_UI_SESSION_KEY", "_web_ui_key")

config :web_ui,
       :signing_salt,
       System.fetch_env!("WEB_UI_SIGNING_SALT")

config :web_ui,
       :encryption_salt,
       System.fetch_env!("WEB_UI_ENCRYPTION_SALT")

config :web_ui, :elm, elm_optimize: true
config :web_ui, :tailwind, minify: true
config :web_ui, :esbuild, minify: true

config :web_ui, WebUi.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: {System.get_env("PORT", "4000"), :integer}],
  url: [
    host: System.get_env("HOST", "example.com"),
    port: {System.get_env("PORT", "80"), :integer},
    scheme: System.get_env("SCHEME", "http")
  ],
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true,
  root: ".",
  secret_key_base: System.fetch_env!("SECRET_KEY_BASE"),
  check_origin: true,
  gzip_static: true,
  websocket_timeout: 30_000,
  force_ssl: [rewrite_on: [:x_forwarded_proto], hsts: true],
  render_errors: [
    view: WebUi.ErrorView,
    accepts: ~w(html json),
    layout: false
  ],
  allow_origin: System.get_env("ALLOWED_ORIGINS", "") |> String.split(",", trim: true)

config :web_ui, WebUi.Plugs.SecurityHeaders,
  csp: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self' ws: wss:; manifest-src 'self'",
  frame_options: "SAMEORIGIN",
  referrer_policy: "strict-origin-when-cross-origin",
  enable_permissions_policy: true

config :logger, level: :info
config :web_ui, :shutdown_timeout, 15_000

config :web_ui, :static,
  at: "/",
  from: "priv/static",
  gzip: true

# SSL/TLS Configuration
#
# To enable HTTPS, configure the https key with your SSL certificate and key:
#
#     config :web_ui, WebUi.Endpoint,
#       https: [
#         port: 443,
#         cipher_suite: :strong,
#         keyfile: System.get_env("SSL_KEY_PATH"),
#         certfile: System.get_env("SSL_CERT_PATH"),
#         cacertfile: System.get_env("SSL_CA_PATH") # Optional
#       ]
#
# Cipher Suite Options:
# - :strong - Use only strong cipher suites (recommended)
# - :compatible - Use compatible cipher suites for older clients
# - {:strong, :moderate} - Mix of strong and moderate
# - [:tls_rsa_with_aes_256_gcm_sha384, ...] - Explicit list
#
# Environment Variables:
# - SSL_KEY_PATH - Path to SSL private key file
# - SSL_CERT_PATH - Path to SSL certificate file
# - SSL_CA_PATH - Path to CA certificate file (optional)
# - PORT - HTTPS port (default: 443)
# - HOST - Your domain name
# - SECRET_KEY_BASE - Secret key for session encryption (required)
# - ALLOWED_ORIGINS - Comma-separated list of allowed WebSocket origins
# - WEB_UI_SESSION_KEY - Session cookie name (default: "_web_ui_key")
# - WEB_UI_SIGNING_SALT - Salt for signing session cookies (required)
# - WEB_UI_ENCRYPTION_SALT - Salt for encrypting session cookies (required)
#
# Generate secure salts with: openssl rand -base64 48
#
# HSTS Configuration:
# The force_ssl option enables HSTS with a max-age of 31536000 (1 year).
# To customize, use:
#
#     force_ssl: [hsts: true, max_age: 31_536_000, subdomains: false, preload: true]
#
# Reverse Proxy Setup:
# If using a reverse proxy (nginx, apache), set the X-Forwarded-Proto header.
# The force_ssl[rewrite_on: [:x_forwarded_proto]] option handles this.
#
# nginx example:
#     location / {
#         proxy_pass http://localhost:4000;
#         proxy_set_header X-Forwarded-Proto $scheme;
#         proxy_set_header Host $host;
#     }
#
# Let's Encrypt:
# For automatic certificate management, use certbot with:
#
#     certbot certonly --webroot -w /var/www/html -d yourdomain.com
#
# Then set SSL_KEY_PATH and SSL_CERT_PATH to:
# - /etc/letsencrypt/live/yourdomain.com/privkey.pem
# - /etc/letsencrypt/live/yourdomain.com/fullchain.pem

config :phoenix, :serve_endpoints, true
