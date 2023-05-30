-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE bookings DROP COLUMN event_id;
ALTER TABLE bookings ADD COLUMN event_id BIGINT DEFAULT NULL;
ALTER TABLE bookings ADD COLUMN cancelled BOOLEAN DEFAULT FALSE;
UPDATE bookings SET cancelled = FALSE WHERE cancelled IS NULL;
ALTER TABLE bookings ADD CONSTRAINT fk_event_metadatas
    FOREIGN KEY (event_id) 
    REFERENCES event_metadatas(id);

CREATE INDEX IF NOT EXISTS index_bookings_event_id_idx ON "bookings" USING btree (event_id);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP INDEX index_bookings_event_id_idx;

ALTER TABLE event_metadatas
  DROP CONSTRAINT fk_event_metadatas;

ALTER TABLE bookings DROP COLUMN event_id;
ALTER TABLE bookings DROP COLUMN cancelled;

ALTER TABLE bookings ADD COLUMN event_id TEXT DEFAULT NULL;
