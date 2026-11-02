import Config

if config_env() != :test do
  database_url = System.get_env("DATABASE_URL")
  operator_token = System.get_env("VADER_OPERATOR_TOKEN")
  secret_key_base = System.get_env("SECRET_KEY_BASE")
  port = String.to_integer(System.get_env("PORT", "4000"))

  if config_env() == :prod and (is_nil(database_url) or is_nil(operator_token) or is_nil(secret_key_base)),
    do: raise("DATABASE_URL, VADER_OPERATOR_TOKEN, and SECRET_KEY_BASE are required")
  if operator_token && byte_size(operator_token) < 32, do: raise("VADER_OPERATOR_TOKEN must contain at least 32 bytes")
  if secret_key_base && byte_size(secret_key_base) < 64, do: raise("SECRET_KEY_BASE must contain at least 64 bytes")
  if port not in 1..65_535, do: raise("Invalid PORT")

  if database_url, do: config(:vader_backend, :database_url, database_url)
  if operator_token, do: config(:vader_backend, :operator_token, operator_token)
  config :vader_backend, VaderBackendWeb.Endpoint,
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base || String.duplicate("dev-only-placeholder-", 4),
    server: not is_nil(database_url),
    check_origin: false
end
