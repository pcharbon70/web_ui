import Config

# Configuration for the test environment

# We don't run a server during tests.
config :web_ui, WebUi.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  url: [host: "localhost"],
  server: false,
  secret_key_base: "test_secret_key_base_for_testing_only",
  root: ".",
  # Disable static asset caching in tests
  cache_static_manifest: nil

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Disable sandbox for tests (can be enabled per test)
config :web_ui, :sql_sandbox, false

# Test-specific configuration
config :web_ui, :start,
  # Don't start the supervision tree in tests by default
  children: []
