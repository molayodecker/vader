-- Vader prototype schema. Apply with psql -v ON_ERROR_STOP=1 -f ...
-- Server-only database roles must own write access: NEVER expose these tables
-- or the dispatch function directly to Android clients.
BEGIN;

CREATE TABLE IF NOT EXISTS vending_orders (
  id uuid PRIMARY KEY,
  machine_id text NOT NULL,
  client_request_id text NOT NULL,
  amount_minor bigint NOT NULL CHECK (amount_minor > 0),
  currency text NOT NULL CHECK (currency IN ('GHS', 'USD')),
  slots jsonb NOT NULL CHECK (jsonb_typeof(slots) = 'array'),
  status text NOT NULL DEFAULT 'awaiting_payment'
    CHECK (status IN ('awaiting_payment','paid','dispensing','complete','needs_review','cancelled')),
  stock_reserved boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (machine_id, client_request_id),
  UNIQUE (id, machine_id)
);

-- Only the backend may create a Paystack settlement AFTER a server-to-server
-- verify call confirms status=success, amount, currency, and reference.
CREATE TABLE IF NOT EXISTS paystack_settlements (
  reference text PRIMARY KEY,
  order_id uuid NOT NULL UNIQUE REFERENCES vending_orders(id),
  amount_minor bigint NOT NULL CHECK (amount_minor > 0),
  currency text NOT NULL CHECK (currency IN ('GHS', 'USD')),
  verified_at timestamptz NOT NULL DEFAULT now()
);

-- MDB peripheral events must be authenticated by a local bridge; its monotonic
-- IDs must survive bridge restart and cannot be derived from wall-clock time.
CREATE TABLE IF NOT EXISTS cash_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id uuid NOT NULL REFERENCES vending_orders(id),
  machine_id text NOT NULL,
  session_id text NOT NULL,
  peripheral_event_id text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('coin','note','change_paid')),
  amount_minor bigint NOT NULL CHECK (amount_minor > 0),
  accepted_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (machine_id, session_id, peripheral_event_id),
  FOREIGN KEY (order_id, machine_id) REFERENCES vending_orders(id, machine_id)
);

-- Trusted machine bridge refreshes telemetry. A stale report MUST fail closed.
CREATE TABLE IF NOT EXISTS machine_safety (
  machine_id text PRIMARY KEY,
  temperature_safe boolean NOT NULL DEFAULT false,
  door_closed boolean NOT NULL DEFAULT false,
  observed_at timestamptz NOT NULL
);

CREATE TABLE IF NOT EXISTS dispense_attempts (
  id uuid PRIMARY KEY,
  order_id uuid NOT NULL UNIQUE REFERENCES vending_orders(id),
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued','sent','confirmed','needs_review')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS dispense_outbox (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  attempt_id uuid NOT NULL UNIQUE REFERENCES dispense_attempts(id),
  topic text NOT NULL DEFAULT 'dispense.requested',
  payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz
);

-- A single transaction enqueues at most one physical vend attempt per order.
-- It does not send commands. Dispatcher must persist sent/uncertain outcomes
-- and must NEVER blindly retry a possibly executed physical vend.
CREATE OR REPLACE FUNCTION queue_dispense(p_order_id uuid, p_attempt_id uuid)
RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE
  o vending_orders%ROWTYPE;
  settled boolean;
BEGIN
  SELECT * INTO o FROM vending_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'order_missing'; END IF;
  IF o.status <> 'awaiting_payment' OR NOT o.stock_reserved THEN
    RETURN false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM machine_safety s WHERE s.machine_id = o.machine_id
      AND s.temperature_safe AND s.door_closed
      AND s.observed_at >= clock_timestamp() - interval '30 seconds'
  ) THEN RETURN false; END IF;

  -- A Paystack settlement or MDB cash (coins + notes) is sufficient, never a
  -- combination of both. Exact change payout must be confirmed for overpayment.
  SELECT (EXISTS (
    SELECT 1 FROM paystack_settlements p WHERE p.order_id = o.id
      AND p.amount_minor = o.amount_minor AND p.currency = o.currency
  ) AND NOT EXISTS (SELECT 1 FROM cash_events c WHERE c.order_id = o.id)) OR
  (NOT EXISTS (SELECT 1 FROM paystack_settlements p WHERE p.order_id = o.id) AND EXISTS (
    SELECT 1 FROM (
      SELECT COALESCE(sum(amount_minor) FILTER (WHERE kind IN ('coin','note')), 0) AS paid,
             COALESCE(sum(amount_minor) FILTER (WHERE kind = 'change_paid'), 0) AS change_paid
      FROM cash_events WHERE order_id = o.id
    ) c WHERE c.paid >= o.amount_minor AND c.change_paid = c.paid - o.amount_minor
  )) INTO settled;

  IF NOT settled THEN RETURN false; END IF;
  IF EXISTS (SELECT 1 FROM dispense_attempts WHERE order_id = o.id) THEN
    RETURN false;
  END IF;

  INSERT INTO dispense_attempts(id, order_id) VALUES (p_attempt_id, o.id);
  INSERT INTO dispense_outbox(attempt_id, payload)
  VALUES (p_attempt_id, jsonb_build_object('order_id', o.id,
    'machine_id', o.machine_id, 'slots', o.slots, 'attempt_id', p_attempt_id));
  UPDATE vending_orders SET status = 'dispensing', updated_at = now()
  WHERE id = o.id;
  RETURN true;
END;
$$;

COMMIT;
