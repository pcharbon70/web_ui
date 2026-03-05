import Config

config :web_ui, WebUi.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5000],
  url: [host: "localhost"],
  pubsub_server: WebUi.PubSub,
  secret_key_base: "K CJQi4YcZkYHkR99YZ5f8CL8KLYDKHVJcMWFTo0YDNFaGLJtY7lPSEvbxDs/x0E",
  root: ".",
  websocket_timeout: 60_000,
  reloadable_patterns: [
    ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$"E,
    ~r"priv/gettext/.*(po)$"E,
    ~r"lib/web_ui/(controllers|views|components|plugs)/.*(ex|heex)$"E
  ],
  watchers: [
    elm: {Mix.Tasks.Compile.Elm, :run, [:force, []]},
    tailwind: ["run", "watch:css", cd: "."]
  ],
  debug_errors: true,
  check_origin: false,
  code_reloader: true,
  gzip_static: false

config :web_ui, :start,
  children: [
    {Phoenix.PubSub, name: WebUi.PubSub},
    {WebUi.Endpoint, []}
  ]

config :web_ui, WebUi.ServerAgentDispatcher,
  agents: [
    WebUi.ServerAgents.CounterAgent
  ]

config :web_ui, WebUi.Plugs.SecurityHeaders,
  csp:
    "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob: ws://localhost:* wss://localhost:*; connect-src 'self' ws://localhost:* wss://localhost:*;"

config :logger, :console,
  format: "[$level] $message\n",
  level: :debug

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :web_ui, :static,
  at: "/",
  from: "priv/static",
  gzip: false
