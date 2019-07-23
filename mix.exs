defmodule Sdk.MixProject do
  use Mix.Project

  def project do
    [
      app: :sdk,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 1.4.0"},
      {:poison, "~> 3.1"},
      {:neuron, "~> 1.2.0"},
      {:mock, "0.3.3", only: :test}
    ]
  end
end
