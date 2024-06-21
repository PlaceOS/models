-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
ALTER TABLE "repo" ADD COLUMN IF NOT EXISTS has_runtime_error BOOL DEFAULT false;
ALTER TABLE "repo" ADD COLUMN IF NOT EXISTS error_message TEXT;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
ALTER TABLE "repo" DROP COLUMN IF EXISTS has_runtime_error;
ALTER TABLE "repo" DROP COLUMN IF EXISTS error_message;