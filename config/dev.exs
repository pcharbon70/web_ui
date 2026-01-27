import Config

config :web_ui, WebUi.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  url: [host: "localhost"],
  secret_key_base: "K CJQi4YcZkYHkR99YZ5f8CL8KLYDKHVJcMWFTo0YDNFaGLJtY7lPSEvbxDs/x0E",
  root: ".",
  websocket_timeout: 60_000,
  reloadable_patterns: [
    ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
    ~r"priv/gettext/.*(po)$",
    ~r"lib/web_ui/(controllers|views|components|plugs)/.*(ex|heex)$"
  ],
  watchers: [
    elm: {Mix.Tasks.Compile.Elm, :run, [:force, []]},
    tailwind:
      {fn ->
         {_, 0} =
           System.cmd(
             if File.exists?("assets/node_modules/.bin/tailwindcss") do
               "assets/node_modules/.bin/tailwindcss"
             else
               "tailwindcss"
             end,
             [
               "--input=assets/css/app.css",
               "--output=priv/static/web_ui/assets/app.css",
               "--watch"
             ],
             cd: File.cwd!(),
             into: IO.stream(:stdio, :line)
           )
       end, :restart}
  ],
  debug_errors: true,
  check_origin: false,
  code_reloader: true,
  gzip_static: false

config :web_ui, WebUi.Plugs.SecurityHeaders,
  csp: "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob: ws://localhost:* wss://localhost:*; connect-src 'self' ws://localhost:* wss://localhost:*;"

config :logger, :console,
  format: "[$level] $message\n",
  level: :debug

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :web_ui, :static,
  at: "/",
  from: "priv/static",
  gzip: false
