import Config

config :phoenix, :json_library, Jason

# Keep WebUI in library mode by default.
# Environment-specific configs can opt-in to starting children.
config :web_ui, :start, children: []

config :web_ui, WebUi.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "counter_example_dev_secret_key_base_change_me_1234567890"

config :web_ui, WebUi.ServerAgentDispatcher, agents: [CounterExample.CounterAgent]

import_config "#{config_env()}.exs"
