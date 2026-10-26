-- Machine-level access boundary. An operator's global role is insufficient
-- to authorize inventory changes on every machine in the fleet.
-- This remains a backend-only primitive; do not expose arbitrary p_operator IDs.
BEGIN;

CREATE TABLE IF NOT EXISTS operator_machine_access (
  operator_id uuid NOT NULL REFERENCES operator_accounts(id),
  machine_id text NOT NULL,
  permission text NOT NULL CHECK (permission IN ('viewer', 'stock_manager')),
  active boolean NOT NULL DEFAULT true,
  granted_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (operator_id, machine_id),
  CHECK (length(trim(machine_id)) > 0)
);

CREATE INDEX IF NOT EXISTS operator_machine_access_machine_idx
  ON operator_machine_access(machine_id, operator_id)
  WHERE active;

-- Revoke casual table oma. The future authenticated API must mediate
-- grants using trusted server-side operator identity, not request parameters.
REVOKE ALL ON operator_machine_access FROM PUBLIC;

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
  IF NOT EXISTS (
    SELECT 1 FROM operator_machine_access oma
    WHERE oma.operator_id = p_operator
      AND oma.machine_id = p_machine
      AND oma.permission = 'stock_manager'
      AND oma.active
  ) THEN
    RAISE EXCEPTION 'operator_machine_access_denied';
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
