-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- Add tags to playlist items (mirrors the tags column on zone)
ALTER TABLE "playlist_items" ADD COLUMN IF NOT EXISTS tags TEXT[] NOT NULL DEFAULT '{}'::TEXT[];

-- GIN index improves @> (contains), <@ (is contained by) and && (overlap) array lookups
CREATE INDEX IF NOT EXISTS playlist_items_tags_idx ON "playlist_items" USING GIN (tags);

-- Refactor playlist scheduling fields (scheduling not yet released, no data to preserve)
ALTER TABLE "playlists" DROP COLUMN IF EXISTS play_hours;
ALTER TABLE "playlists" DROP COLUMN IF EXISTS play_at_period;

-- play_cron becomes required with a sane default (midnight every day)
UPDATE "playlists" SET play_cron = '0 0 * * *' WHERE play_cron IS NULL;
ALTER TABLE "playlists" ALTER COLUMN play_cron SET DEFAULT '0 0 * * *';
ALTER TABLE "playlists" ALTER COLUMN play_cron SET NOT NULL;

-- how many minutes a scheduled playlist plays for (defaults to one day)
ALTER TABLE "playlists" ADD COLUMN IF NOT EXISTS play_period INTEGER NOT NULL DEFAULT 1440;

ALTER TABLE "playlists" RENAME COLUMN play_at_takeover TO play_takeover;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "playlists" RENAME COLUMN play_takeover TO play_at_takeover;
ALTER TABLE "playlists" DROP COLUMN IF EXISTS play_period;
ALTER TABLE "playlists" ALTER COLUMN play_cron DROP NOT NULL;
ALTER TABLE "playlists" ALTER COLUMN play_cron DROP DEFAULT;
ALTER TABLE "playlists" ADD COLUMN IF NOT EXISTS play_at_period INTEGER;
ALTER TABLE "playlists" ADD COLUMN IF NOT EXISTS play_hours TEXT;

DROP INDEX IF EXISTS playlist_items_tags_idx;

ALTER TABLE "playlist_items" DROP COLUMN IF EXISTS tags;
