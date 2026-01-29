import Config

config :web_ui, WebUi.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  url: [host: "localhost"],
  server: false,
  secret_key_base: "test_secret_key_base_for_testing_only",
  root: ".",
  websocket_timeout: 5000,
  cache_static_manifest: false,
  gzip_static: false,
  allowed_origins: ["http://localhost:*"],
  pubsub_server: WebUi.PubSub

config :web_ui, WebUi.Plugs.SecurityHeaders,
  enable_permissions_policy: false,
  enable_xss_protection: false

# Enable rate limiting in tests so we can test the functionality
config :web_ui, WebUi.Plugs.RateLimit,
  enabled: true,
  default_limits: [
    {100, 60_000}
  ],
  cleanup_interval: 60_000

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
config :web_ui, :sql_sandbox, false

config :web_ui, :start,
  children: [
    # Start PubSub for WebSocket testing
    {Phoenix.PubSub,
     [
       name: WebUi.PubSub,
       adapter: Phoenix.PubSub.PG2,
       adapter_name: :web_ui_pubsub_test
     ]},
    # Start Endpoint for integration testing
    {WebUi.Endpoint, []}
  ]
