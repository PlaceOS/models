-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
ALTER TABLE "event_metadatas" DROP COLUMN IF EXISTS setup_event_id;
ALTER TABLE "event_metadatas" DROP COLUMN IF EXISTS breakdown_event_id;
ALTER TABLE "event_metadatas" ADD COLUMN IF NOT EXISTS setup_event_id TEXT DEFAULT NULL;
ALTER TABLE "event_metadatas" ADD COLUMN IF NOT EXISTS breakdown_event_id TEXT DEFAULT NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
ALTER TABLE "event_metadatas" DROP COLUMN IF EXISTS setup_event_id;
ALTER TABLE "event_metadatas" DROP COLUMN IF EXISTS breakdown_event_id;
ALTER TABLE "event_metadatas" ADD COLUMN IF NOT EXISTS setup_event_id bigint DEFAULT NULL;
ALTER TABLE "event_metadatas" ADD COLUMN IF NOT EXISTS breakdown_event_id bigint DEFAULT NULL;
