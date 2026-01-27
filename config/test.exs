import Config

config :web_ui, WebUi.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  url: [host: "localhost"],
  server: false,
  secret_key_base: "test_secret_key_base_for_testing_only",
  root: ".",
  websocket_timeout: 5000,
  cache_static_manifest: nil,
  gzip_static: false,
  allowed_origins: ["http://localhost:*"]

config :web_ui, WebUi.Plugs.SecurityHeaders,
  enable_permissions_policy: false,
  enable_xss_protection: false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
config :web_ui, :sql_sandbox, false

config :web_ui, :start,
  children: []
