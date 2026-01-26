import Config

# Configuration for the development environment

# For development, we disable cache and enable debugging and code reloading.
config :web_ui, WebUi.Endpoint,
  # Binding to localhost ensures only the development machine can access
  # the server. You can change this to listen on all interfaces by setting
  # it to [0, 0, 0, 0].
  http: [ip: {127, 0, 0, 1}, port: 4000],
  url: [host: "localhost"],
  # Secret key base is generated dynamically for development
  secret_key_base: "K CJQi4YcZkYHkR99YZ5f8CL8KLYDKHVJcMWFTo0YDNFaGLJtY7lPSEvbxDs/x0E",
  root: ".",
  # Enable code reloading
  reloadable_patterns: [
    ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
    ~r"priv/gettext/.*(po)$",
    ~r"lib/web_ui/(controllers|views|components)/.*(ex|heex)$"
  ],
  # Watchers for external asset compilation
  watchers: [
    elm: {Mix.Tasks.Compile.Elm, :run, [:force, []]},
    tailwind: {fn ->
      {_, 0} = System.cmd(
        if File.exists?("assets/node_modules/.bin/tailwindcss") do
          "assets/node_modules/.bin/tailwindcss"
        else
          "tailwindcss"
        end,
        ["--input=assets/css/app.css",
         "--output=priv/static/web_ui/assets/app.css",
         "--watch"],
        cd: File.cwd!(),
        into: IO.stream(:stdio, :line)
      )
    end, :restart}
  ],
  # Enable debugging
  debug_errors: true,
  check_origin: false,
  code_reloader: true

# Log level - show all logs in development
config :logger, :console,
  format: "[$level] $message\n",
  level: :debug

# Set a higher stacktrace during development.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Static asset configuration for development
config :web_ui, :static,
  at: "/",
  from: "priv/static",
  gzip: false

