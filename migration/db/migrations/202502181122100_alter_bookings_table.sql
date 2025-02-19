-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS all_day BOOL DEFAULT false;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
ALTER TABLE "bookings" DROP COLUMN IF EXISTS all_day;