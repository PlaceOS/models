-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- 1. Add `locatable` with default TRUE and NOT NULL in one step
ALTER TABLE "user"
  ADD COLUMN locatable BOOLEAN NOT NULL DEFAULT true;

-- 2. Add `photo_upload_id` with an inline FK that sets null on delete
ALTER TABLE "user"
  ADD COLUMN photo_upload_id TEXT
    REFERENCES uploads(id) ON DELETE SET NULL;

-- 3. Add `tags` to `uploads` as a non-null TEXT[] with an empty‐array default
ALTER TABLE uploads
  ADD COLUMN tags TEXT[] NOT NULL DEFAULT '{}';

CREATE INDEX idx_uploads_tags
  ON uploads
  USING GIN (tags);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

-- 1. Drop `photo_upload_id` (this also removes the FK constraint automatically)
ALTER TABLE "user"
  DROP COLUMN photo_upload_id;

-- 2. Drop `locatable`
ALTER TABLE "user"
  DROP COLUMN locatable;

-- 3. Drop `tags`
ALTER TABLE uploads
  DROP COLUMN tags;
