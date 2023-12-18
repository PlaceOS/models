-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "event_metadatas" ADD COLUMN IF NOT EXISTS resource_master_id TEXT;
CREATE INDEX IF NOT EXISTS event_metadatas_resource_master_id_idx ON event_metadatas USING HASH (resource_master_id);


-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP INDEX IF EXISTS event_metadatas_resource_master_id_idx;
ALTER TABLE "event_metadatas" DROP COLUMN IF EXISTS resource_master_id;
