defmodule VaderBackendWeb.OperatorAuthTest do
  use ExUnit.Case, async: false
  import Plug.Test

  setup do
    original = Application.get_env(:vader_backend, :operator_token)
    token = String.duplicate("s", 40)
    Application.put_env(:vader_backend, :operator_token, token)
    on_exit(fn ->
      if original, do: Application.put_env(:vader_backend, :operator_token, original),
        else: Application.delete_env(:vader_backend, :operator_token)
    end)
    %{token: token}
  end

  test "missing token is rejected" do
    conn = conn(:get, "/api/v1/machines") |> VaderBackendWeb.OperatorAuth.call([])
    assert conn.status == 401
    assert conn.halted
  end

  test "wrong token is rejected" do
    conn = conn(:get, "/api/v1/machines")
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> String.duplicate("x", 40))
      |> VaderBackendWeb.OperatorAuth.call([])
    assert conn.status == 401
  end

  test "exact bearer token is allowed", %{token: token} do
    conn = conn(:get, "/api/v1/machines")
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
      |> VaderBackendWeb.OperatorAuth.call([])
    refute conn.halted
  end
end
