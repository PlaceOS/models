-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE ONLY "oauth_access_grants"
    DROP CONSTRAINT IF EXISTS fk_oauth_access_grants_on_oauth_applications_id,
    ADD CONSTRAINT fk_oauth_access_grants_on_oauth_applications_id 
    FOREIGN KEY (application_id) REFERENCES "oauth_applications"(id)
    ON DELETE CASCADE;


ALTER TABLE ONLY "oauth_access_tokens"
    DROP CONSTRAINT IF EXISTS fk_oauth_access_tokens_on_oauth_applications_id,
    ADD CONSTRAINT fk_oauth_access_tokens_on_oauth_applications_id 
    FOREIGN KEY (application_id) REFERENCES "oauth_applications"(id)
    ON DELETE CASCADE;


ALTER TABLE ONLY "attendees"
    DROP CONSTRAINT IF EXISTS attendees_booking_id_fkey,
    ADD CONSTRAINT attendees_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES "bookings"(id)
    ON DELETE CASCADE;

ALTER TABLE "bookings"
    DROP CONSTRAINT IF EXISTS fk_event_metadatas,
    ADD CONSTRAINT fk_event_metadatas
    FOREIGN KEY (event_id) 
    REFERENCES "event_metadatas"(id)
    ON DELETE CASCADE;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
