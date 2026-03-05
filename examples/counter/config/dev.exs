import Config

config :web_ui, :start,
  children: [
    {Phoenix.PubSub,
     [
       name: CounterExample.PubSub,
       adapter: Phoenix.PubSub.PG2,
       adapter_name: :counter_example_pubsub
     ]},
    {WebUi.Endpoint, []}
  ]

config :web_ui, WebUi.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4100],
  url: [host: "localhost", port: 4100],
  server: true,
  pubsub_server: CounterExample.PubSub,
  check_origin: false,
  code_reloader: false,
  gzip_static: false,
  websocket_timeout: 60_000
