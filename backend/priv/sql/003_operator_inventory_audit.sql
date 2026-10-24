BEGIN;
CREATE TABLE IF NOT EXISTS operator_accounts (
  id uuid PRIMARY KEY,
  email text NOT NULL UNIQUE,
  role text NOT NULL CHECK (role IN ('viewer','manager')),
  active boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS inventory_adjustments (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  machine_id text NOT NULL,
  slot_code text NOT NULL,
  operator_id uuid NOT NULL REFERENCES operator_accounts(id),
  request_key text NOT NULL,
  before_quantity integer NOT NULL CHECK (before_quantity >= 0),
  after_quantity integer NOT NULL CHECK (after_quantity >= 0),
  reason text NOT NULL CHECK (length(trim(reason)) >= 8),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(machine_id, request_key),
  FOREIGN KEY(machine_id, slot_code) REFERENCES machine_slots(machine_id, slot_code)
);
CREATE INDEX IF NOT EXISTS inventory_adjustments_slot_idx
  ON inventory_adjustments(machine_id, slot_code, created_at DESC);

CREATE OR REPLACE FUNCTION reject_inventory_audit_edits()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'inventory_audit_append_only';
END;
$$;
DROP TRIGGER IF EXISTS inventory_adjustments_immutable ON inventory_adjustments;
CREATE TRIGGER inventory_adjustments_immutable BEFORE UPDATE OR DELETE
  ON inventory_adjustments FOR EACH ROW EXECUTE FUNCTION reject_inventory_audit_edits();

-- The backend must derive p_operator from an authenticated session.
-- Never expose this function to the kiosk or accept an arbitrary actor ID.
CREATE OR REPLACE FUNCTION operator_set_slot_stock(
  p_operator uuid, p_machine text, p_slot text, p_quantity integer,
  p_reason text, p_request_key text
) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE
  current_slot machine_slots%ROWTYPE;
  previous inventory_adjustments%ROWTYPE;
  event_id bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM operator_accounts
                 WHERE id=p_operator AND role='manager' AND active) THEN
    RAISE EXCEPTION 'operator_not_authorized';
  END IF;
  IF p_quantity IS NULL OR p_quantity < 0
     OR p_reason IS NULL OR length(trim(p_reason)) < 8 OR length(p_reason) > 500
     OR p_request_key IS NULL OR length(p_request_key) < 8 OR length(p_request_key) > 128 THEN
    RAISE EXCEPTION 'invalid_adjustment';
  END IF;

  SELECT * INTO current_slot FROM machine_slots
    WHERE machine_id=p_machine AND slot_code=p_slot FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'slot_not_found'; END IF;

  SELECT * INTO previous FROM inventory_adjustments
    WHERE machine_id=p_machine AND request_key=p_request_key;
  IF FOUND THEN
    IF previous.slot_code=p_slot AND previous.operator_id=p_operator
       AND previous.after_quantity=p_quantity AND previous.reason=p_reason THEN
      RETURN previous.id;
    END IF;
    RAISE EXCEPTION 'idempotency_key_conflict';
  END IF;
  IF p_quantity > current_slot.capacity THEN RAISE EXCEPTION 'capacity_exceeded'; END IF;
  IF EXISTS (SELECT 1 FROM vending_orders o WHERE o.machine_id=p_machine
      AND o.stock_reserved AND o.status IN ('awaiting_payment','dispensing','needs_review')
      AND o.slots @> jsonb_build_array(p_slot)) THEN
    RAISE EXCEPTION 'active_reservation_requires_reconciliation';
  END IF;

  UPDATE machine_slots SET quantity=p_quantity, updated_at=now()
    WHERE machine_id=p_machine AND slot_code=p_slot;
  INSERT INTO inventory_adjustments(machine_id,slot_code,operator_id,
      request_key,before_quantity,after_quantity,reason)
  VALUES(p_machine,p_slot,p_operator,p_request_key,
      current_slot.quantity,p_quantity,p_reason) RETURNING id INTO event_id;
  RETURN event_id;
END;
$$;
REVOKE ALL ON FUNCTION operator_set_slot_stock(uuid,text,text,integer,text,text) FROM PUBLIC;
COMMIT;
