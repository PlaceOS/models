-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS parent_id bigint DEFAULT NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
ALTER TABLE "bookings" DROP COLUMN IF EXISTS parent_id;