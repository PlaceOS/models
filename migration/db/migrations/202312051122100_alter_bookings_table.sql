-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS asset_ids TEXT[] DEFAULT '{}';
UPDATE "bookings" SET asset_ids[1] = asset_id WHERE asset_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS bookings_asset_ids_idx ON bookings USING GIN (asset_ids);


-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP INDEX IF EXISTS bookings_asset_ids_idx;
ALTER TABLE "bookings" DROP COLUMN IF EXISTS asset_ids;