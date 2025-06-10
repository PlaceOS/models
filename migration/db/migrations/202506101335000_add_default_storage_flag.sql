-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE storages
  ADD COLUMN is_default BOOLEAN NOT NULL DEFAULT FALSE;

-- This will prevent more than one row per authority_id ever having is_default = TRUE.
CREATE UNIQUE INDEX storages_authority_default_idx
  ON storages(authority_id)
  WHERE is_default = TRUE;

-- Trigger function to auto-unset any other storages with is_default = TRUE
CREATE OR REPLACE FUNCTION storages_ensure_single_default()
  RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_default THEN
    -- serialize per-authority with an advisory lock
    PERFORM pg_advisory_xact_lock(hashtext(NEW.authority_id)::bigint);
    UPDATE storages
      SET is_default = FALSE
     WHERE authority_id = NEW.authority_id
       AND id <> NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- it will automatically flip any other row for that same tenant back to FALSE
CREATE TRIGGER trg_storages_single_default
  BEFORE INSERT OR UPDATE ON storages
  FOR EACH ROW
  WHEN (NEW.is_default = TRUE)
  EXECUTE FUNCTION storages_ensure_single_default();

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

-- 1. Drop the trigger
DROP TRIGGER IF EXISTS trg_storages_single_default
  ON storages;

-- 2. Drop the trigger function
DROP FUNCTION IF EXISTS storages_ensure_single_default()
  CASCADE;

-- 3. Drop the partial unique index
DROP INDEX IF EXISTS storages_authority_default_idx;

-- 4. Drop the is_default column
ALTER TABLE storages
  DROP COLUMN IF EXISTS is_default;
