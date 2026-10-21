-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- booking type => maximum length of a booking in minutes
ALTER TABLE "tenants" ADD COLUMN IF NOT EXISTS booking_period JSONB NOT NULL DEFAULT '{}'::jsonb;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "tenants" DROP COLUMN IF EXISTS booking_period;
