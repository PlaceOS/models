-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE ONLY "attendees"
    ALTER COLUMN booking_id
    TYPE bigint USING booking_id::bigint;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
