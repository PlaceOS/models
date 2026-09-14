-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- booking type => number of days from now a booking can be made
ALTER TABLE "tenants" ADD COLUMN IF NOT EXISTS booking_range JSONB NOT NULL DEFAULT '{}'::jsonb;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "tenants" DROP COLUMN IF EXISTS booking_range;
