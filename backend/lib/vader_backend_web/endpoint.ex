defmodule VaderBackendWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :vader_backend

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason
  plug VaderBackendWeb.Router
end
