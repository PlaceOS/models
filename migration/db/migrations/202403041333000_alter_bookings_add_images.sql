-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS images TEXT[] DEFAULT '{}'::text[];

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "bookings" DROP COLUMN IF EXISTS images;
