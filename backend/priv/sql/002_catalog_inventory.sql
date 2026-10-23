-- Run AFTER 001_vending_orders.sql. All writes are backend/operator-only.
BEGIN;

CREATE TABLE IF NOT EXISTS catalog_products (
  id text PRIMARY KEY,
  name text NOT NULL CHECK (length(trim(name)) > 0),
  description text NOT NULL DEFAULT '',
  image_url text,
  price_minor bigint NOT NULL CHECK (price_minor > 0),
  currency text NOT NULL CHECK (currency IN ('GHS','USD')),
  active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- One machine slot stocks one product. Physical capacities require inspection;
-- this table initially reflects operator-entered estimates, not live sensors.
CREATE TABLE IF NOT EXISTS machine_slots (
  machine_id text NOT NULL,
  slot_code text NOT NULL CHECK (length(trim(slot_code)) > 0),
  product_id text NOT NULL REFERENCES catalog_products(id),
  quantity integer NOT NULL CHECK (quantity >= 0),
  capacity integer NOT NULL CHECK (capacity > 0),
  enabled boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (machine_id, slot_code),
  CHECK (quantity <= capacity)
);

CREATE TABLE IF NOT EXISTS machine_heartbeats (
  machine_id text PRIMARY KEY,
  app_version text,
  android_version text,
  connectivity text NOT NULL CHECK (connectivity IN ('online','degraded','offline')),
  observed_at timestamptz NOT NULL,
  CHECK (app_version IS NULL OR length(app_version) <= 100),
  CHECK (android_version IS NULL OR length(android_version) <= 100)
);

CREATE OR REPLACE VIEW machine_inventory_status AS
SELECT s.machine_id, s.slot_code, s.product_id, p.name AS product_name,
       p.price_minor, p.currency, s.quantity, s.capacity,
       (s.enabled AND p.active AND s.quantity > 0) AS available
FROM machine_slots s JOIN catalog_products p ON p.id = s.product_id;

-- Call this within a transaction after a server-created order. It locks all
-- requested slots in stable order to prevent concurrent overselling, ensures
-- all products are available, and validates the exact order-price snapshot.
CREATE OR REPLACE FUNCTION reserve_order_inventory(p_order_id uuid)
RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE
  o vending_orders%ROWTYPE;
  expected_lines integer;
  found_lines integer;
  total_minor bigint;
  requested_units integer;
BEGIN
  SELECT * INTO o FROM vending_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND OR o.status <> 'awaiting_payment' OR o.stock_reserved THEN
    RETURN false;
  END IF;
  IF jsonb_typeof(o.slots) <> 'array' OR jsonb_array_length(o.slots) = 0
     OR jsonb_array_length(o.slots) > 100 THEN RETURN false; END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(o.slots) v
             WHERE jsonb_typeof(v) <> 'string' OR length(v #>> '{}') = 0) THEN
    RETURN false;
  END IF;

  -- Lock the exact slots, avoiding races with other reservations and refills.
  PERFORM 1 FROM machine_slots s WHERE s.machine_id = o.machine_id
    AND s.slot_code IN (SELECT value #>> '{}' FROM jsonb_array_elements(o.slots) value)
    ORDER BY s.slot_code FOR UPDATE;

  SELECT count(*), COALESCE(sum(q.units), 0), COALESCE(sum(p.price_minor * q.units), 0)
    INTO found_lines, requested_units, total_minor
  FROM (
    SELECT value #>> '{}' AS slot_code, count(*)::integer AS units
    FROM jsonb_array_elements(o.slots) value GROUP BY 1
  ) q
  JOIN machine_slots s ON s.machine_id = o.machine_id AND s.slot_code = q.slot_code
  JOIN catalog_products p ON p.id = s.product_id
  WHERE s.enabled AND p.active AND s.quantity >= q.units AND p.currency = o.currency;

  SELECT count(*) INTO expected_lines FROM (
    SELECT DISTINCT value #>> '{}' FROM jsonb_array_elements(o.slots) value
  ) requested;
  IF found_lines <> expected_lines OR total_minor <> o.amount_minor THEN
    RETURN false;
  END IF;

  UPDATE machine_slots s SET quantity = s.quantity - q.units, updated_at = now()
  FROM (
    SELECT value #>> '{}' AS slot_code, count(*)::integer AS units
    FROM jsonb_array_elements(o.slots) value GROUP BY 1
  ) q WHERE s.machine_id = o.machine_id AND s.slot_code = q.slot_code;
  UPDATE vending_orders SET stock_reserved = true, updated_at = now()
  WHERE id = o.id;
  RETURN true;
END;
$$;

-- Restock only orders that have never reached paid/dispensing. The caller must
-- separately reconcile any accepted cash before cancelling a cash session.
CREATE OR REPLACE FUNCTION cancel_unpaid_reserved_order(p_order_id uuid)
RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE
  o vending_orders%ROWTYPE;
BEGIN
  SELECT * INTO o FROM vending_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND OR o.status <> 'awaiting_payment' THEN RETURN false; END IF;
  IF EXISTS (SELECT 1 FROM paystack_settlements WHERE order_id = p_order_id)
     OR EXISTS (SELECT 1 FROM cash_events WHERE order_id = p_order_id) THEN
    RETURN false;
  END IF;

  IF o.stock_reserved THEN
    PERFORM 1 FROM machine_slots s WHERE s.machine_id = o.machine_id
      AND s.slot_code IN (SELECT value #>> '{}' FROM jsonb_array_elements(o.slots) value)
      ORDER BY s.slot_code FOR UPDATE;
    -- Refills/slot reassignment while reserved orders exist need separate
    -- operator-controlled workflows; do not silently overflow capacity.
    IF EXISTS (
      SELECT 1 FROM (
        SELECT value #>> '{}' AS slot_code, count(*)::integer AS units
        FROM jsonb_array_elements(o.slots) value GROUP BY 1
      ) q LEFT JOIN machine_slots s ON s.machine_id = o.machine_id AND s.slot_code = q.slot_code
      WHERE s.slot_code IS NULL OR s.quantity + q.units > s.capacity
    ) THEN RETURN false; END IF;
    UPDATE machine_slots s SET quantity = s.quantity + q.units, updated_at = now()
    FROM (
      SELECT value #>> '{}' AS slot_code, count(*)::integer AS units
      FROM jsonb_array_elements(o.slots) value GROUP BY 1
    ) q WHERE s.machine_id = o.machine_id AND s.slot_code = q.slot_code;
  END IF;
  UPDATE vending_orders SET status = 'cancelled', stock_reserved = false, updated_at = now()
  WHERE id = o.id;
  RETURN true;
END;
$$;

COMMIT;
