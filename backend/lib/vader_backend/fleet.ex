defmodule VaderBackend.Fleet do
  @moduledoc """
  Read-only PostgreSQL queries. Vendor-cloud observations are kept separate from
  live heartbeat telemetry. No API method can command hardware or settle money.
  """

  def machines do
    query("""
    SELECT r.id, r.name, r.platform, r.upper_software_version,
           r.motor_description, r.reported_shelf_amount,
           r.control_board_version, r.mdb_version,
           CASE WHEN h.observed_at >= now() - interval '5 minutes' AND h.connectivity = 'online'
                THEN 'online' ELSE 'offline' END AS connectivity,
           h.observed_at AS last_seen_at, h.android_version,
           COALESCE(stock.units, 0)::bigint AS stock_units
    FROM machine_registry r
    LEFT JOIN machine_heartbeats h ON h.machine_id = r.id
    LEFT JOIN (
      SELECT machine_id, SUM(quantity) AS units FROM machine_slots GROUP BY machine_id
    ) stock ON stock.machine_id = r.id
    ORDER BY r.id LIMIT 500
    """)
  end

  def products do
    query("""
    SELECT id, name, description, image_url, price_minor, currency, active, updated_at
    FROM catalog_products ORDER BY id LIMIT 2000
    """)
  end

  def slots do
    query("""
    SELECT machine_id, slot_code, product_id, quantity, capacity, available
    FROM machine_inventory_status ORDER BY machine_id, slot_code LIMIT 10000
    """)
  end

  def inventory(machine_id) do
    query("""
    SELECT machine_id, slot_code, product_id, product_name, price_minor,
           currency, quantity, capacity, available
    FROM machine_inventory_status WHERE machine_id = $1
    ORDER BY slot_code LIMIT 1000
    """, [machine_id])
  end

  def orders do
    query("""
    SELECT id::text, machine_id, amount_minor, currency, status, created_at
    FROM vending_orders ORDER BY created_at DESC LIMIT 50
    """)
  end

  defp query(sql, params \\ []) do
    case Postgrex.query(VaderBackend.DB, sql, params, timeout: 5000) do
      {:ok, %{columns: columns, rows: rows}} ->
        {:ok, Enum.map(rows, &Map.new(Enum.zip(columns, &1)))}
      {:error, _reason} -> {:error, :database_unavailable}
    end
  rescue
    _ -> {:error, :database_unavailable}
  end
end
