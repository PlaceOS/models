-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE playlist_revisions ALTER COLUMN user_id DROP NOT NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE playlist_revisions ALTER COLUMN user_id SET NOT NULL;
