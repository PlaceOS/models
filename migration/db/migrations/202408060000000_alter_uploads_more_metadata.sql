-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "playlist_items" ADD COLUMN IF NOT EXISTS video_length INTEGER DEFAULT NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "playlist_items" DROP COLUMN IF EXISTS video_length;
