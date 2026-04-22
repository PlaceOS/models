-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE sys
  ADD COLUMN IF NOT EXISTS signage_last_seen TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS playlist_item_id TEXT;

ALTER TABLE sys
  DROP CONSTRAINT IF EXISTS sys_playlist_item_id_fkey;

ALTER TABLE sys
  ADD CONSTRAINT sys_playlist_item_id_fkey
  FOREIGN KEY (playlist_item_id)
  REFERENCES playlist_items(id)
  ON DELETE SET NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE sys
  DROP CONSTRAINT IF EXISTS sys_playlist_item_id_fkey;

ALTER TABLE sys
  DROP COLUMN IF EXISTS playlist_item_id,
  DROP COLUMN IF EXISTS signage_last_seen;
