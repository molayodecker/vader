DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM machine_registry
    WHERE id = '19265359' AND name = 'M19265359'
      AND platform = 'Android' AND upper_software_version = '3.1.90'
      AND reported_shelf_amount = 100
      AND control_board_version IS NULL AND mdb_version IS NULL
  ) THEN
    RAISE EXCEPTION 'Zhongda registry profile missing or inferred unknown versions';
  END IF;
END $$;
