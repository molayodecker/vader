-- Operator-entered physical-machine identity. Does not authorize dispensing.
BEGIN;
CREATE TABLE IF NOT EXISTS machine_registry (
  id text PRIMARY KEY,
  name text NOT NULL,
  platform text,
  upper_software_version text,
  motor_description text,
  reported_shelf_amount integer CHECK (reported_shelf_amount > 0),
  control_board_version text,
  mdb_version text,
  registered_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO machine_registry
  (id, name, platform, upper_software_version, motor_description, reported_shelf_amount)
VALUES
  ('19265359', 'M19265359', 'Android', '3.1.90', '3-wire single-feedback', 100)
ON CONFLICT (id) DO NOTHING;
COMMIT;
