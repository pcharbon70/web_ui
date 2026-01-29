import Config

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing
config :phoenix, :json_library, Jason

# Elm compiler configuration
config :web_ui, :elm,
  elm_path: "assets/elm",
  elm_main: "Main",
  elm_output: "priv/static/web_ui/assets",
  # Set to true in prod.exs for optimization
  elm_optimize: false

# Tailwind CSS configuration
config :web_ui, :tailwind,
  input: "assets/css/app.css",
  output: "priv/static/web_ui/assets/app.css",
  config: "assets/tailwind.config.js",
  # Set to true in prod.exs for minification
  minify: false

# esbuild configuration
config :web_ui, :esbuild,
  entry: "assets/js/web_ui_interop.js",
  output: "priv/static/web_ui/assets/interop.js",
  # Set to true in prod.exs for minification
  minify: false

# Assets configuration
config :web_ui, :assets, output_dir: "priv/static/web_ui/assets"

# Application startup configuration
# By default, WebUI runs in library mode and doesn't start its supervision tree.
# To start the supervision tree, configure children in your app's config:
#
#   config :web_ui, :start,
#     children: [
#       {WebUi.Endpoint, []},
#       # Add other children as needed
#     ]
#
# Or use the default children:
#
#   config :web_ui, :start,
#     children: WebUi.Application.default_children()
config :web_ui, :start, children: []

# Session Security Configuration
#
# For production, always set strong, unique salts via environment variables.
# You can generate secure salts with: openssl rand -base64 48
#
# Environment variables:
#   - WEB_UI_SESSION_KEY - Cookie name (default: "_web_ui_key")
#   - WEB_UI_SIGNING_SALT - Salt for signing session cookies
#   - WEB_UI_ENCRYPTION_SALT - Salt for encrypting session cookies
#
# Development defaults are provided, but do NOT use these in production!
config :web_ui,
       :session_key,
       System.get_env("WEB_UI_SESSION_KEY", "_web_ui_key")

config :web_ui,
       :signing_salt,
       System.get_env("WEB_UI_SIGNING_SALT", "dev_signing_salt_only")

config :web_ui,
       :encryption_salt,
       System.get_env("WEB_UI_ENCRYPTION_SALT", "dev_encryption_salt_only")

# Graceful shutdown timeout (milliseconds)
# Can be overridden per environment
config :web_ui, :shutdown_timeout, 30_000

# Static asset serving configuration
config :web_ui, :static,
  at: "/",
  from: "priv/static",
  gzip: false

# Server-side flags to pass to the Elm application
# These can be extended in your application's config
config :web_ui,
       :server_flags,
       # Add default flags here
       %{}

# WebSocket configuration
config :web_ui, :websocket,
  heartbeat_interval: 30_000,
  timeout: 60_000

# CloudEvents configuration
config :web_ui, :cloudevents,
  specversion: "1.0",
  default_datacontenttype: "application/json"

# Telemetry configuration
# You can attach handlers to these events in your application
config :web_ui,
       :telemetry,
       # Attach telemetry handlers here if needed
       []

# Import environment specific configs
import_config "#{config_env()}.exs"
