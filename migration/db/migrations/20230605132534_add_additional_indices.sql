-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- PPT-431
CREATE INDEX IF NOT EXISTS index_bookings_user_id_email_digest_idx ON "bookings" USING btree (user_id, email_digest);

-- PPT-432
CREATE INDEX IF NOT EXISTS index_attendees_booking_id ON "attendees" USING btree (booking_id);
CREATE INDEX IF NOT EXISTS index_guests_searchable ON "guests" USING btree (searchable);
 
-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP INDEX IF EXISTS index_bookings_user_id_email_digest_idx;
DROP INDEX IF EXISTS index_attendees_booking_id;
DROP INDEX IF EXISTS index_guests_searchable;