-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE asset ADD COLUMN IF NOT EXISTS zone_id TEXT;
CREATE INDEX IF NOT EXISTS index_asset_zone_id_idx ON "asset" USING btree (zone_id);

ALTER TABLE "asset"
ADD CONSTRAINT fk_zone
FOREIGN KEY (zone_id)
REFERENCES zone(id)
ON DELETE CASCADE;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP INDEX index_asset_zone_id_idx;
ALTER TABLE asset DROP COLUMN zone_id;
