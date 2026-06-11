-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- Booking instances can override the parent booking's approval state and
-- asset allocation. All columns are nullable: NULL = inherit from the parent
-- (mirrors the existing process_state / extension_data override pattern).
ALTER TABLE "booking_instances"
  ADD COLUMN IF NOT EXISTS approved BOOLEAN,
  ADD COLUMN IF NOT EXISTS approved_at BIGINT,
  ADD COLUMN IF NOT EXISTS rejected BOOLEAN,
  ADD COLUMN IF NOT EXISTS rejected_at BIGINT,
  ADD COLUMN IF NOT EXISTS approver_id TEXT,
  ADD COLUMN IF NOT EXISTS approver_name TEXT,
  ADD COLUMN IF NOT EXISTS approver_email TEXT,
  ADD COLUMN IF NOT EXISTS asset_id TEXT,
  ADD COLUMN IF NOT EXISTS asset_ids TEXT[];

CREATE INDEX IF NOT EXISTS index_booking_instances_asset_ids_idx
  ON public.booking_instances USING gin (asset_ids);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP INDEX IF EXISTS index_booking_instances_asset_ids_idx;

ALTER TABLE "booking_instances"
  DROP COLUMN IF EXISTS approved,
  DROP COLUMN IF EXISTS approved_at,
  DROP COLUMN IF EXISTS rejected,
  DROP COLUMN IF EXISTS rejected_at,
  DROP COLUMN IF EXISTS approver_id,
  DROP COLUMN IF EXISTS approver_name,
  DROP COLUMN IF EXISTS approver_email,
  DROP COLUMN IF EXISTS asset_id,
  DROP COLUMN IF EXISTS asset_ids;
