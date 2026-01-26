import Config

# Configuration for the development environment

# For development, we disable cache and enable debugging and code reloading.
config :web_ui, WebUi.Endpoint,
  # Binding to localhost ensures only the development machine can access
  # the server. You can change this to listen on all interfaces by setting
  # it to [0, 0, 0, 0].
  http: [ip: {127, 0, 0, 1}, port: 4000],
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
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
