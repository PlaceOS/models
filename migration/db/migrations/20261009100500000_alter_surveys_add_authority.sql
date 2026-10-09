-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- surveys belong to an authority. Nullable so existing surveys can be adopted by staff-api,
-- the model requires it for new and updated surveys
ALTER TABLE "surveys" ADD COLUMN IF NOT EXISTS authority_id TEXT;
CREATE INDEX IF NOT EXISTS index_surveys_authority_id ON "surveys" USING btree (authority_id);
ALTER TABLE "surveys" DROP CONSTRAINT IF EXISTS surveys_authority_id_fkey;
ALTER TABLE "surveys"
  ADD CONSTRAINT surveys_authority_id_fkey FOREIGN KEY (authority_id)
  REFERENCES authority(id) ON DELETE CASCADE;

-- zone_id and building_id reference zones. Empty strings, and zones that no longer exist,
-- become NULL so the foreign keys can be added; deleting a zone now clears the reference
UPDATE "surveys" SET zone_id = NULL
  WHERE zone_id = '' OR NOT EXISTS (SELECT 1 FROM zone WHERE zone.id = surveys.zone_id);
UPDATE "surveys" SET building_id = NULL
  WHERE building_id = '' OR NOT EXISTS (SELECT 1 FROM zone WHERE zone.id = surveys.building_id);

CREATE INDEX IF NOT EXISTS index_surveys_zone_id ON "surveys" USING btree (zone_id);
CREATE INDEX IF NOT EXISTS index_surveys_building_id ON "surveys" USING btree (building_id);
ALTER TABLE "surveys" DROP CONSTRAINT IF EXISTS surveys_zone_id_fkey;
ALTER TABLE "surveys"
  ADD CONSTRAINT surveys_zone_id_fkey FOREIGN KEY (zone_id)
  REFERENCES zone(id) ON DELETE SET NULL;
ALTER TABLE "surveys" DROP CONSTRAINT IF EXISTS surveys_building_id_fkey;
ALTER TABLE "surveys"
  ADD CONSTRAINT surveys_building_id_fkey FOREIGN KEY (building_id)
  REFERENCES zone(id) ON DELETE SET NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "surveys" DROP CONSTRAINT IF EXISTS surveys_building_id_fkey;
ALTER TABLE "surveys" DROP CONSTRAINT IF EXISTS surveys_zone_id_fkey;
DROP INDEX IF EXISTS index_surveys_building_id;
DROP INDEX IF EXISTS index_surveys_zone_id;
ALTER TABLE "surveys" DROP CONSTRAINT IF EXISTS surveys_authority_id_fkey;
DROP INDEX IF EXISTS index_surveys_authority_id;
ALTER TABLE "surveys" DROP COLUMN IF EXISTS authority_id;
