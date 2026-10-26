-- Per-machine inventory permissions are enforced independently of global role.
BEGIN;

INSERT INTO operator_accounts(id,email,role) VALUES
 ('00000000-0000-0000-0000-000000000301','fleet-manager@example.test','manager'),
 ('00000000-0000-0000-0000-000000000302','fleet-viewer@example.test','viewer');

INSERT INTO catalog_products(id,name,price_minor,currency)
VALUES ('access-water','Water',500,'GHS');
INSERT INTO machine_slots(machine_id,slot_code,product_id,quantity,capacity,enabled)
VALUES
 ('scope-machine-a','A1','access-water',2,8,true),
 ('scope-machine-b','A1','access-water',2,8,true);

DO $$
DECLARE v_event bigint;
BEGIN
  -- Global manager role alone must not grant access to all machines.
  BEGIN
    PERFORM operator_set_slot_stock(
      '00000000-0000-0000-0000-000000000301',
      'scope-machine-a','A1',4,'Initial refill authorized','scope-key-0001');
    RAISE EXCEPTION 'missing_grant_bypass';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'operator_machine_access_denied' THEN RAISE; END IF;
  END;

  INSERT INTO operator_machine_access(operator_id,machine_id,permission)
  VALUES
    ('00000000-0000-0000-0000-000000000301','scope-machine-a','viewer'),
    ('00000000-0000-0000-0000-000000000302','scope-machine-b','stock_manager');

  -- Machine viewer cannot write even when globally a manager.
  BEGIN
    PERFORM operator_set_slot_stock(
      '00000000-0000-0000-0000-000000000301',
      'scope-machine-a','A1',4,'Refill without grant','scope-key-0002');
    RAISE EXCEPTION 'viewer_permission_bypass';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'operator_machine_access_denied' THEN RAISE; END IF;
  END;

  -- A machine stock_manager grant cannot elevate a global viewer.
  BEGIN
    PERFORM operator_set_slot_stock(
      '00000000-0000-0000-0000-000000000302',
      'scope-machine-b','A1',4,'Viewer role escalation','scope-key-0003');
    RAISE EXCEPTION 'global_role_bypass';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'operator_not_authorized' THEN RAISE; END IF;
  END;

  UPDATE operator_machine_access SET permission='stock_manager'
  WHERE operator_id='00000000-0000-0000-0000-000000000301'
    AND machine_id='scope-machine-a';

  v_event := operator_set_slot_stock(
    '00000000-0000-0000-0000-000000000301',
    'scope-machine-a','A1',4,'Refilled only machine A','scope-key-0004');
  IF v_event IS NULL OR
    (SELECT quantity FROM machine_slots
     WHERE machine_id='scope-machine-a' AND slot_code='A1') <> 4
    OR (SELECT quantity FROM machine_slots
        WHERE machine_id='scope-machine-b' AND slot_code='A1') <> 2 THEN
    RAISE EXCEPTION 'scope_grant_failed';
  END IF;
  IF operator_set_slot_stock(
    '00000000-0000-0000-0000-000000000301',
    'scope-machine-a','A1',4,'Refilled only machine A','scope-key-0004'
  ) <> v_event THEN RAISE EXCEPTION 'idempotent_grant_retry_failed'; END IF;

  -- Machine B remains inaccessible, even with a global manager role.
  BEGIN
    PERFORM operator_set_slot_stock(
      '00000000-0000-0000-0000-000000000301',
      'scope-machine-b','A1',4,'Refilled other machine','scope-key-0005');
    RAISE EXCEPTION 'cross_machine_bypass';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'operator_machine_access_denied' THEN RAISE; END IF;
  END;

  UPDATE operator_machine_access SET active=false
  WHERE operator_id='00000000-0000-0000-0000-000000000301'
    AND machine_id='scope-machine-a';
  -- Revocation applies even to a previous request key.
  BEGIN
    PERFORM operator_set_slot_stock(
      '00000000-0000-0000-0000-000000000301',
      'scope-machine-a','A1',4,'Refilled only machine A','scope-key-0004');
    RAISE EXCEPTION 'revoked_grant_bypass';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'operator_machine_access_denied' THEN RAISE; END IF;
  END;
END $$;
ROLLBACK;
