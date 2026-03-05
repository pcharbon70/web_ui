defmodule CounterExample.MixProject do
  use Mix.Project

  def project do
    [
      app: :counter_example,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {CounterExample.Application, []}
    ]
  end

  defp deps do
    [
      {:web_ui, path: "../.."}
    ]
  end

  defp aliases do
    [
      server: ["run --no-halt"]
    ]
  end
end
