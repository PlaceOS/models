-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE mod
  ADD COLUMN IF NOT EXISTS analytics_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS analytics_interval_minutes INTEGER NOT NULL DEFAULT 5;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE mod
  DROP COLUMN IF EXISTS analytics_enabled,
  DROP COLUMN IF EXISTS analytics_interval_minutes;
