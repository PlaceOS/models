-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE event_metadatas ADD COLUMN IF NOT EXISTS cancelled BOOLEAN DEFAULT FALSE;
UPDATE event_metadatas SET cancelled = FALSE WHERE cancelled IS NULL;

ALTER TABLE bookings DROP COLUMN event_id;
ALTER TABLE bookings ADD COLUMN event_id BIGINT DEFAULT NULL;

ALTER TABLE bookings ADD CONSTRAINT fk_event_metadatas
    FOREIGN KEY (event_id) 
    REFERENCES event_metadatas(id);

CREATE INDEX IF NOT EXISTS index_bookings_event_id_idx ON "bookings" USING btree (event_id);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE event_metadatas DROP COLUMN cancelled;

DROP INDEX index_bookings_event_id_idx;
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS fk_event_metadatas;
ALTER TABLE bookings DROP COLUMN event_id;
ALTER TABLE bookings ADD COLUMN event_id TEXT DEFAULT NULL;
