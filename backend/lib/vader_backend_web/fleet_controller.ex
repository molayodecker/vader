defmodule VaderBackendWeb.FleetController do
  use Phoenix.Controller, formats: [:json]

  def snapshot(conn, _params) do
    with {:ok, machines} <- VaderBackend.Fleet.machines(),
         {:ok, products} <- VaderBackend.Fleet.products(),
         {:ok, slots} <- VaderBackend.Fleet.slots(),
         {:ok, orders} <- VaderBackend.Fleet.orders() do
      json(conn, %{source: "postgres", machines: machines, products: products, slots: slots, orders: orders})
    else
      _ -> unavailable(conn)
    end
  end

  def machines(conn, _params), do: respond(conn, VaderBackend.Fleet.machines())
  def orders(conn, _params), do: respond(conn, VaderBackend.Fleet.orders())

  def inventory(conn, %{"machine_id" => id}) do
    if byte_size(id) > 0 and byte_size(id) <= 128 and
         String.match?(id, ~r/\A[a-zA-Z0-9_-]+\z/) do
      respond(conn, VaderBackend.Fleet.inventory(id))
    else
      conn |> put_status(400) |> json(%{error: "invalid_machine_id"})
    end
  end

  defp respond(conn, {:ok, rows}), do: json(conn, %{data: rows})
  defp respond(conn, _), do: unavailable(conn)
  defp unavailable(conn), do: conn |> put_status(503) |> json(%{error: "database_unavailable"})
end
