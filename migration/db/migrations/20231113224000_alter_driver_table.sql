-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
ALTER TABLE "driver" ADD COLUMN IF NOT EXISTS update_available BOOL DEFAULT false;
ALTER TABLE "driver" ADD COLUMN IF NOT EXISTS update_info JSONB;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
ALTER TABLE "driver" DROP COLUMN IF EXISTS update_available;
ALTER TABLE "driver" DROP COLUMN IF EXISTS update_info