-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "user"
  ADD COLUMN IF NOT EXISTS logged_out_at TIMESTAMP;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "user"
  DROP COLUMN IF EXISTS logged_out_at;
