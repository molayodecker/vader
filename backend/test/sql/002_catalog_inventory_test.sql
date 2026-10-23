BEGIN;
INSERT INTO catalog_products(id, name, price_minor, currency)
VALUES ('water', 'Water', 200, 'GHS'), ('juice', 'Juice', 350, 'GHS');
INSERT INTO machine_slots(machine_id, slot_code, product_id, quantity, capacity, enabled)
VALUES ('machine-inventory', 'A1', 'water', 3, 5, true),
       ('machine-inventory', 'A2', 'juice', 1, 3, true),
       ('machine-inventory', 'A3', 'water', 1, 1, false);
INSERT INTO vending_orders(id, machine_id, client_request_id, amount_minor, currency, slots)
VALUES ('00000000-0000-0000-0000-000000000101', 'machine-inventory', 'cart-1', 750, 'GHS', '["A1","A1","A2"]'),
       ('00000000-0000-0000-0000-000000000102', 'machine-inventory', 'cart-2', 750, 'GHS', '["A1","A1","A2"]'),
       ('00000000-0000-0000-0000-000000000103', 'machine-inventory', 'cart-3', 1, 'GHS', '["A1"]'),
       ('00000000-0000-0000-0000-000000000104', 'machine-inventory', 'cart-4', 200, 'GHS', '["A3"]'),
       ('00000000-0000-0000-0000-000000000105', 'machine-inventory', 'cart-5', 200, 'GHS', '["A1"]');

DO $$ BEGIN
  IF NOT reserve_order_inventory('00000000-0000-0000-0000-000000000101') THEN
    RAISE EXCEPTION 'first cart reservation failed';
  END IF;
  IF (SELECT quantity FROM machine_slots WHERE machine_id = 'machine-inventory' AND slot_code = 'A1') <> 1 THEN
    RAISE EXCEPTION 'two water units not deducted';
  END IF;
  IF (SELECT quantity FROM machine_slots WHERE machine_id = 'machine-inventory' AND slot_code = 'A2') <> 0 THEN
    RAISE EXCEPTION 'juice not deducted';
  END IF;
  IF reserve_order_inventory('00000000-0000-0000-0000-000000000101') THEN
    RAISE EXCEPTION 'duplicate reservation allowed';
  END IF;
  IF reserve_order_inventory('00000000-0000-0000-0000-000000000102') THEN
    RAISE EXCEPTION 'oversold sold-out item';
  END IF;
  IF reserve_order_inventory('00000000-0000-0000-0000-000000000103') THEN
    RAISE EXCEPTION 'accepted incorrect price';
  END IF;
  IF reserve_order_inventory('00000000-0000-0000-0000-000000000104') THEN
    RAISE EXCEPTION 'accepted disabled slot';
  END IF;
  IF NOT cancel_unpaid_reserved_order('00000000-0000-0000-0000-000000000101') THEN
    RAISE EXCEPTION 'cancellation failed';
  END IF;
  IF (SELECT quantity FROM machine_slots WHERE machine_id = 'machine-inventory' AND slot_code = 'A1') <> 3 THEN
    RAISE EXCEPTION 'stock not restored';
  END IF;
  IF cancel_unpaid_reserved_order('00000000-0000-0000-0000-000000000101') THEN
    RAISE EXCEPTION 'duplicate cancellation allowed';
  END IF;
END $$;

-- Any accepted cash blocks the simple cancellation path; reconciliation is required.
DO $$ BEGIN
  IF NOT reserve_order_inventory('00000000-0000-0000-0000-000000000105') THEN
    RAISE EXCEPTION 'second successful reservation failed';
  END IF;
END $$;
INSERT INTO cash_events(order_id, machine_id, session_id, peripheral_event_id, kind, amount_minor)
VALUES ('00000000-0000-0000-0000-000000000105', 'machine-inventory', 'cash-session', 'coin-1', 'coin', 100);
DO $$ BEGIN
  IF cancel_unpaid_reserved_order('00000000-0000-0000-0000-000000000105') THEN
    RAISE EXCEPTION 'cancelled order with accepted cash';
  END IF;
END $$;
ROLLBACK;
