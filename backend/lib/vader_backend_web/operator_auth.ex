defmodule VaderBackendWeb.OperatorAuth do
  @behaviour Plug
  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    expected = Application.get_env(:vader_backend, :operator_token)
    presented =
      case get_req_header(conn, "authorization") do
        ["Bearer " <> token] -> token
        _ -> ""
      end

    if is_binary(expected) and byte_size(expected) >= 32 and
         byte_size(expected) == byte_size(presented) and
         Plug.Crypto.secure_compare(expected, presented) do
      conn
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(401, Jason.encode!(%{error: "unauthorized"}))
      |> halt()
    end
  end
end
