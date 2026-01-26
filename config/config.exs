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
  elm_optimize: false  # Set to true in prod.exs for optimization

# Tailwind CSS configuration
config :web_ui, :tailwind,
  input: "assets/css/app.css",
  output: "priv/static/web_ui/assets/app.css",
  config: "assets/tailwind.config.js",
  minify: false  # Set to true in prod.exs for minification

# esbuild configuration
config :web_ui, :esbuild,
  entry: "assets/js/web_ui_interop.js",
  output: "priv/static/web_ui/assets/interop.js",
  minify: false  # Set to true in prod.exs for minification

# Assets configuration
config :web_ui, :assets,
  output_dir: "priv/static/web_ui/assets"

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
config :web_ui, :start,
  children: []

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
config :web_ui, :server_flags,
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
config :web_ui, :telemetry,
  # Attach telemetry handlers here if needed
  []

# Import environment specific configs
import_config "#{config_env()}.exs"
