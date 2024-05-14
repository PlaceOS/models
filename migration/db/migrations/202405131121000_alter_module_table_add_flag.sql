-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
ALTER TABLE "mod" ADD COLUMN IF NOT EXISTS has_runtime_error BOOL DEFAULT false;
ALTER TABLE "mod" ADD COLUMN IF NOT EXISTS error_timestamp TIMESTAMPTZ;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
ALTER TABLE "mod" DROP COLUMN IF EXISTS has_runtime_error;
ALTER TABLE "mod" DROP COLUMN IF EXISTS error_timestamp;