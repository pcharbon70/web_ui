import Config

# Configuration for the production environment

# The production configuration uses runtime configuration.
# This means you can configure it via environment variables instead of
# compile-time configuration.
config :web_ui, WebUi.Endpoint,
  http: [
    ip: {0, 0, 0, 0, 0},
    port: 4000
  ],
  url: [host: "example.com", port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json"

# Do not print debug messages in production
config :logger, level: :info

# Runtime configuration
config :web_ui, WebUi.Endpoint,
  server: true,
  root: ".",
  secret_key_base: System.get_env("SECRET_KEY_BASE")

# ## SSL Support
#
# To get SSL working, you will need to add the `https` key
# to your endpoint configuration:
#
#     config :web_ui, WebUi.Endpoint,
#       https: [
#         port: 443,
#         cipher_suite: :strong,
#         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
#         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
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

# ## Configuring the mailer
#
# In production you need to configure the mailer and the allowed hosts:
#
#     config :web_ui, WebUi.Mailer,
#       adapter: Swoosh.Adapters.Postmark,
#       api_key: System.get_env("POSTMARK_API_KEY")
#
#     config :swoosh, :api_client, Swoosh.ApiClient.Finch

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
