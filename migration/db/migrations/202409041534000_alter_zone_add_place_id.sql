-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "zone" ADD COLUMN IF NOT EXISTS place_id TEXT;
CREATE INDEX IF NOT EXISTS zone_place_id_index ON "zone" USING BTREE (place_id);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "zone" DROP COLUMN IF EXISTS place_id;
