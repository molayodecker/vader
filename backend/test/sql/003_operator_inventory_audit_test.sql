BEGIN;
INSERT INTO operator_accounts(id,email,role) VALUES
('00000000-0000-0000-0000-000000000201','manager@example.test','manager'),
('00000000-0000-0000-0000-000000000202','viewer@example.test','viewer');
INSERT INTO catalog_products(id,name,price_minor,currency)
VALUES ('audit-water','Water',500,'GHS');
INSERT INTO machine_slots(machine_id,slot_code,product_id,quantity,capacity,enabled)
VALUES ('audit-machine','A1','audit-water',3,8,true);

DO $$
DECLARE first_id bigint; second_id bigint;
BEGIN
  first_id:=operator_set_slot_stock('00000000-0000-0000-0000-000000000201',
    'audit-machine','A1',6,'Restocked by operator','refill-0000001');
  second_id:=operator_set_slot_stock('00000000-0000-0000-0000-000000000201',
    'audit-machine','A1',6,'Restocked by operator','refill-0000001');
  IF first_id<>second_id OR (SELECT count(*) FROM inventory_adjustments)<>1
    OR (SELECT quantity FROM machine_slots WHERE machine_id='audit-machine' AND slot_code='A1')<>6
  THEN RAISE EXCEPTION 'idempotency_or_stock_failure'; END IF;

  BEGIN
    PERFORM operator_set_slot_stock('00000000-0000-0000-0000-000000000202',
      'audit-machine','A1',7,'Viewer tried refill','refill-0000002');
    RAISE EXCEPTION 'viewer_bypass';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM='viewer_bypass' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM operator_set_slot_stock('00000000-0000-0000-0000-000000000201',
      'audit-machine','A1',9,'Over capacity refill','refill-0000003');
    RAISE EXCEPTION 'capacity_bypass';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM='capacity_bypass' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM operator_set_slot_stock('00000000-0000-0000-0000-000000000201',
      'audit-machine','A1',5,'Conflicting retry','refill-0000001');
    RAISE EXCEPTION 'idempotency_bypass';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM='idempotency_bypass' THEN RAISE; END IF;
  END;
END $$;

INSERT INTO vending_orders(id,machine_id,client_request_id,amount_minor,currency,slots,stock_reserved)
VALUES ('00000000-0000-0000-0000-000000000203','audit-machine','held',500,'GHS','["A1"]',true);
DO $$ BEGIN
  BEGIN
    PERFORM operator_set_slot_stock('00000000-0000-0000-0000-000000000201',
      'audit-machine','A1',5,'While order pending','refill-0000004');
    RAISE EXCEPTION 'reservation_bypass';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM='reservation_bypass' THEN RAISE; END IF;
  END;
END $$;
ROLLBACK;
