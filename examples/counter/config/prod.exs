import Config

config :web_ui, :start, children: []

config :web_ui, WebUi.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: {System.get_env("PORT", "4100"), :integer}],
  url: [
    host: System.get_env("HOST", "example.com"),
    port: {System.get_env("PORT", "4100"), :integer},
    scheme: System.get_env("SCHEME", "http")
  ],
  server: true,
  secret_key_base: System.fetch_env!("SECRET_KEY_BASE")
