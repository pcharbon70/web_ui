defmodule WebUi.MixProject do
  use Mix.Project

  def project do
    [
      app: :web_ui,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Compilers for Elixir and Elm
      # Note: :elm compiler is optional - requires elm to be installed
      compilers: compilers(Mix.env()),
      # Aliases for common asset tasks
      aliases: aliases(),
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

  # Only enable Elm compiler if the module is available
  defp compilers(env) when env in [:dev, :prod] do
    if Code.ensure_loaded?(Mix.Tasks.Compile.Elm) do
      [:elm] ++ Mix.compilers()
    else
      Mix.compilers()
    end
  end

  defp compilers(_env), do: Mix.compilers()

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {WebUi.Application, []},
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

  # Aliases for common tasks
  defp aliases do
    [
      # Asset tasks
      "assets.build": &build_assets/1,
      "assets.clean": ["assets.clean"],
      "assets.watch": ["assets.watch"],

      # Setup tasks
      setup: ["deps.get", "cmd --cd assets npm install"],

      # Development tasks
      "dev.build": ["compile", "assets.build"],
      "dev.clean": ["clean", "assets.clean"],

      # Test tasks
      "test.elm": ["cmd --cd assets elm-test"]
    ]
  end

  # Build all assets (wrapper for npm scripts)
  defp build_assets(args) do
    Mix.Task.run("assets.build", args)

    # Also run npm build scripts if node_modules exists
    if File.dir?("assets/node_modules") do
      Mix.shell().cmd("npm run build", cd: "assets")
    else
      Mix.shell().info([
        :yellow,
        "Note: Run 'mix setup' to install npm dependencies",
        :reset
      ])
    end
  end
end
