import Config

config :vader_backend, VaderBackendWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [formats: [json: VaderBackendWeb.ErrorJSON], layout: false],
  pubsub_server: VaderBackend.PubSub

config :phoenix, :json_library, Jason

if config_env() == :test, do: import_config("test.exs")
