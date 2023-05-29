-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE bookings DROP COLUMN event_id;
ALTER TABLE bookings ADD COLUMN event_id BIGINT DEFAULT NULL;
ALTER TABLE bookings ADD CONSTRAINT fk_event_metadatas
    FOREIGN KEY (event_id) 
    REFERENCES event_metadatas(id);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE event_metadatas
  DROP CONSTRAINT fk_event_metadatas;

ALTER TABLE bookings DROP COLUMN event_id;

ALTER TABLE bookings ADD COLUMN event_id TEXT DEFAULT NULL;
