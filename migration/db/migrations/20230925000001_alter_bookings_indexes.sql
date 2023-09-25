-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

CREATE INDEX IF NOT EXISTS bookings_booked_by_id_idx ON bookings USING HASH (booked_by_id);

DROP INDEX IF EXISTS bookings_parent_id_idx;
CREATE INDEX IF NOT EXISTS bookings_parent_id_idx ON bookings USING HASH (parent_id);

-- re-create some existing indexes for improved performance
DROP INDEX IF EXISTS index_bookings_booking_email_digest_idx;
CREATE INDEX IF NOT EXISTS bookings_email_digest_idx ON bookings USING HASH (email_digest);

DROP INDEX IF EXISTS index_bookings_booking_user_id_idx;
CREATE INDEX IF NOT EXISTS bookings_user_id_idx ON bookings USING HASH (user_id);

DROP INDEX IF EXISTS index_bookings_event_id_idx;
CREATE INDEX IF NOT EXISTS bookings_event_id_idx ON bookings USING HASH (event_id);

DROP INDEX IF EXISTS index_bookings_tenant_id;
CREATE INDEX IF NOT EXISTS bookings_tenant_id_idx ON bookings USING HASH (tenant_id);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
