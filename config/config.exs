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

# Import environment specific configs
import_config "#{config_env()}.exs"
