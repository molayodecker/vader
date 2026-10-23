defmodule VaderBackend.MixProject do
  use Mix.Project

  def project do
    [app: :vader_backend, version: "0.1.0", elixir: "~> 1.16", start_permanent: Mix.env() == :prod,
     deps: [], test_coverage: [summary: [threshold: 90]]]
  end

  def application, do: [extra_applications: [:logger]]
end
