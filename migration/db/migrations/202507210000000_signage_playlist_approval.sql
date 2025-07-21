-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE playlist_revisions
  ADD COLUMN IF NOT EXISTS approved BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS approved_by_id TEXT,
  ADD COLUMN IF NOT EXISTS approved_by_name TEXT,
  ADD COLUMN IF NOT EXISTS approved_by_email TEXT,
  ADD CONSTRAINT fk_playlist_revisions_approved_by_id
    FOREIGN KEY (approved_by_id)
    REFERENCES "user"(id)
    ON DELETE SET NULL,
  ADD CONSTRAINT fk_playlist_revisions_user_id
    FOREIGN KEY (user_id)
    REFERENCES "user"(id)
    ON DELETE SET NULL;

UPDATE playlist_revisions
  SET approved = TRUE;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE playlist_revisions
  DROP CONSTRAINT IF EXISTS fk_playlist_revisions_user_id,
  DROP CONSTRAINT IF EXISTS fk_playlist_revisions_approved_by_id;

ALTER TABLE playlist_revisions
  DROP COLUMN IF EXISTS approved,
  DROP COLUMN IF EXISTS approved_by_id,
  DROP COLUMN IF EXISTS approved_by_name,
  DROP COLUMN IF EXISTS approved_by_email;
