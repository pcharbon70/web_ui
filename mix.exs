defmodule WebUi.MixProject do
  use Mix.Project

  def project do
    [
      app: :web_ui,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Compilers - Elm compiler will be added in section 1.3
      compilers: Mix.compilers(),
      # Hex package configuration
      package: package(),
      description: description(),
      docs: docs(),
      dialyzer: [
        plt_add_apps: [:ex_unit, :mix, :iex],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :telemetry]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Phoenix Framework
      {:phoenix, "~> 1.7"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_pubsub, "~> 2.1"},

      # JSON codec
      {:jason, "~> 1.4"},

      # Metrics and instrumentation
      {:telemetry, "~> 1.2"},

      # Precise numeric handling
      {:decimal, "~> 2.0"},

      # Optional: Jido agent framework
      {:jido, "~> 1.2", optional: true},

      # Development and test dependencies
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.30", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      name: "web_ui",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/user/web_ui"}
    ]
  end

  defp description do
    """
    WebUI - An Elixir library for building web applications with Elm frontend,
    Phoenix backend, and CloudEvents communication.
    """
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_url: "https://github.com/user/web_ui"
    ]
  end
end
