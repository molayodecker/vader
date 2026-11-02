import Config

config :vader_backend, VaderBackendWeb.Endpoint,
  server: false,
  secret_key_base: String.duplicate("a", 64)
