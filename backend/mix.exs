defmodule VaderBackend.MixProject do
  use Mix.Project

  def project do
    [app: :vader_backend, version: "0.2.0", elixir: "~> 1.16", start_permanent: Mix.env() == :prod,
     deps: deps(), test_coverage: [summary: [threshold: 90]]]
  end

  def application, do: [mod: {VaderBackend.Application, []}, extra_applications: [:logger]]

  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:plug_cowboy, "~> 2.7"},
      {:postgrex, "~> 0.19"},
      {:jason, "~> 1.4"}
    ]
  end
end
