-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "repo" ADD COLUMN IF NOT EXISTS root_path TEXT DEFAULT NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "repo" DROP COLUMN IF EXISTS root_path;
