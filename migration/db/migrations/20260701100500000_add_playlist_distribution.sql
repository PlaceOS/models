-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- Flag a playlist as a distribution container: each item carries its own
-- schedule (via playlist_item_schedules) instead of the playlist-level schedule.
ALTER TABLE "playlists"
  ADD COLUMN IF NOT EXISTS distribution BOOLEAN NOT NULL DEFAULT FALSE;

-- Per-item schedules for distribution playlists. Each row wraps a single
-- playlist_item and is owned 1:1 by a distribution playlist.
CREATE TABLE IF NOT EXISTS "playlist_item_schedules" (
  id TEXT NOT NULL PRIMARY KEY,

  playlist_id TEXT NOT NULL REFERENCES "playlists"(id) ON DELETE CASCADE,
  item_id TEXT NOT NULL REFERENCES "playlist_items"(id) ON DELETE CASCADE,

  schedules JSONB NOT NULL DEFAULT '[]'::jsonb,

  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS playlist_item_schedules_playlist_id_index
  ON "playlist_item_schedules" USING BTREE (playlist_id);
CREATE INDEX IF NOT EXISTS playlist_item_schedules_item_id_index
  ON "playlist_item_schedules" USING BTREE (item_id);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP INDEX IF EXISTS playlist_item_schedules_item_id_index;
DROP INDEX IF EXISTS playlist_item_schedules_playlist_id_index;
DROP TABLE IF EXISTS "playlist_item_schedules";

ALTER TABLE "playlists" DROP COLUMN IF EXISTS distribution;
