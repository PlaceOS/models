-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- Replace the single-schedule columns with a JSONB array of schedules.
-- (scheduling not yet in use, no data to preserve)
ALTER TABLE "playlists" DROP COLUMN IF EXISTS play_at;
ALTER TABLE "playlists" DROP COLUMN IF EXISTS play_cron;
ALTER TABLE "playlists" DROP COLUMN IF EXISTS play_period;
ALTER TABLE "playlists" DROP COLUMN IF EXISTS play_takeover;

ALTER TABLE "playlists" ADD COLUMN IF NOT EXISTS schedules JSONB NOT NULL DEFAULT '[]'::jsonb;

-- Track approval requests on a playlist revision (mirrors the approved_by_id pattern).
ALTER TABLE "playlist_revisions"
  ADD COLUMN IF NOT EXISTS approval_requested BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS requested_by_id TEXT,
  ADD CONSTRAINT fk_playlist_revisions_requested_by_id
    FOREIGN KEY (requested_by_id)
    REFERENCES "user"(id)
    ON DELETE SET NULL;

-- Booking instances inherit + can override the parent booking's process_state
-- (mirrors `process_state text` + index on `bookings`).
ALTER TABLE "booking_instances" ADD COLUMN IF NOT EXISTS process_state TEXT;
CREATE INDEX IF NOT EXISTS index_booking_instances_process_state_idx
  ON public.booking_instances USING btree (process_state);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP INDEX IF EXISTS index_booking_instances_process_state_idx;
ALTER TABLE "booking_instances" DROP COLUMN IF EXISTS process_state;

ALTER TABLE "playlist_revisions"
  DROP CONSTRAINT IF EXISTS fk_playlist_revisions_requested_by_id;

ALTER TABLE "playlist_revisions"
  DROP COLUMN IF EXISTS approval_requested,
  DROP COLUMN IF EXISTS requested_by_id;

ALTER TABLE "playlists" DROP COLUMN IF EXISTS schedules;

ALTER TABLE "playlists" ADD COLUMN IF NOT EXISTS play_at BIGINT;
ALTER TABLE "playlists" ADD COLUMN IF NOT EXISTS play_cron TEXT NOT NULL DEFAULT '0 0 * * *';
ALTER TABLE "playlists" ADD COLUMN IF NOT EXISTS play_period INTEGER NOT NULL DEFAULT 1440;
ALTER TABLE "playlists" ADD COLUMN IF NOT EXISTS play_takeover BOOLEAN NOT NULL DEFAULT FALSE;
