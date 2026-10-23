BEGIN;
INSERT INTO vending_orders(id, machine_id, client_request_id, amount_minor, currency, slots, stock_reserved)
VALUES ('00000000-0000-0000-0000-000000000001', 'machine-a', 'client-1', 500, 'GHS', '["A1"]', true),
       ('00000000-0000-0000-0000-000000000002', 'machine-a', 'client-2', 500, 'GHS', '["A2"]', true),
       ('00000000-0000-0000-0000-000000000003', 'machine-a', 'client-3', 500, 'GHS', '["A3"]', true);
INSERT INTO machine_safety(machine_id, temperature_safe, door_closed, observed_at)
VALUES ('machine-a', true, true, now());

-- Unpaid order cannot queue.
DO $$ BEGIN
  IF queue_dispense('00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001') THEN
    RAISE EXCEPTION 'unpaid order queued';
  END IF;
END $$;

INSERT INTO paystack_settlements(reference, order_id, amount_minor, currency)
VALUES ('paystack-1', '00000000-0000-0000-0000-000000000001', 500, 'GHS');

DO $$ BEGIN
  IF NOT queue_dispense('00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001') THEN
    RAISE EXCEPTION 'verified settlement not queued';
  END IF;
  IF queue_dispense('00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002') THEN
    RAISE EXCEPTION 'duplicate attempt queued';
  END IF;
END $$;

INSERT INTO cash_events(order_id, machine_id, session_id, peripheral_event_id, kind, amount_minor)
VALUES ('00000000-0000-0000-0000-000000000002', 'machine-a', 'session-2', 'coin-1', 'coin', 200);
DO $$ BEGIN
  IF queue_dispense('00000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000003') THEN
    RAISE EXCEPTION 'partial cash queued';
  END IF;
END $$;
INSERT INTO cash_events(order_id, machine_id, session_id, peripheral_event_id, kind, amount_minor)
VALUES ('00000000-0000-0000-0000-000000000002', 'machine-a', 'session-2', 'note-1', 'note', 300),
       ('00000000-0000-0000-0000-000000000003', 'machine-a', 'session-3', 'note-1', 'note', 1000);
DO $$ BEGIN
  IF NOT queue_dispense('00000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000003') THEN
    RAISE EXCEPTION 'exact cash not queued';
  END IF;
  IF queue_dispense('00000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000004') THEN
    RAISE EXCEPTION 'cash overpayment without change queued';
  END IF;
END $$;
INSERT INTO cash_events(order_id, machine_id, session_id, peripheral_event_id, kind, amount_minor)
VALUES ('00000000-0000-0000-0000-000000000003', 'machine-a', 'session-3', 'change-1', 'change_paid', 500);
DO $$ BEGIN
  IF NOT queue_dispense('00000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000004') THEN
    RAISE EXCEPTION 'cash with confirmed change not queued';
  END IF;
  IF (SELECT count(*) FROM dispense_outbox) <> 3 THEN
    RAISE EXCEPTION 'unexpected outbox count';
  END IF;
END $$;
ROLLBACK;
