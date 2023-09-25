-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

CREATE INDEX IF NOT EXISTS bookings_parent_id_idx ON bookings (parent_id);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP INDEX IF EXISTS bookings_parent_id_idx;
