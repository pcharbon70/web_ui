import Config

# Configuration for the production environment

# Optimize assets for production
config :web_ui, :elm, elm_optimize: true

config :web_ui, :tailwind, minify: true

config :web_ui, :esbuild, minify: true

# The production configuration uses runtime configuration.
# This means you can configure it via environment variables instead of
# compile-time configuration.
config :web_ui, WebUi.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  url: [host: System.get_env("HOST", "example.com"), port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true,
  root: ".",
  # Secret key base must be set via environment variable
  secret_key_base: System.fetch_env!("SECRET_KEY_BASE"),
  # Production settings
  check_origin: true,
  gzip: true,
  # Force SSL in production (recommended)
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  # Logging configuration
  render_errors: [
    view: WebUi.ErrorView,
    accepts: ~w(html json),
    layout: false
  ]

# Do not print debug messages in production
config :logger, level: :info

# Graceful shutdown timeout for production
config :web_ui, :shutdown_timeout, 15_000

# Static asset configuration for production
config :web_ui, :static,
  at: "/",
  from: "priv/static",
  gzip: true

# ## SSL Support
#
# To get SSL working, you will need to add the `https` key
# to your endpoint configuration:
#
#     config :web_ui, WebUi.Endpoint,
#       https: [
#         port: 443,
#         cipher_suite: :strong,
#         keyfile: System.get_env("SSL_KEY_PATH"),
#         certfile: System.get_env("SSL_CERT_PATH")
#       ]
#
# The `cipher_suite` is set to `:strong` to use only the
# strongest and most secure cipher suites.
#
# You may also configure the cipher suite by specifying a list of
# cipher suite names separated by commas, e.g.:
#
#     cipher_suite: [:tls_rsa_with_aes_256_gcm_sha384, :tls_rsa_with_aes_128_gcm_sha256]
#
# Or by specifying a list of cipher suites in the form of "{strong, moderate}"
#
#     cipher_suite: {:strong, :moderate}
#
# See https://www.erlang.org/doc/man/ssl.html#cipher_suite/1
# for available cipher suite values and ordering.

# ## Using releases
#
# If you use `mix release`, you need to instruct Phoenix
# to start the server for all endpoints:
#
#     config :phoenix, :serve_endpoints, true
#
# Alternatively, you can configure exactly which server to
# start per endpoint:
#
#     config :web_ui, WebUi.Endpoint, server: true
#
# You may also configure a different port for the HTTP server:
#
#     config :web_ui, WebUi.Endpoint, http: [port: 4001]
#
# Note that if you configure `http: [port: 4001]` instead of `server: true`,
# the web server will still be started but will no longer be accessible
# from the internet.
