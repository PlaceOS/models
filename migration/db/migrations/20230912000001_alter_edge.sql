-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
ALTER TABLE "edge" ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ NULL;
ALTER TABLE "edge" ADD COLUMN IF NOT EXISTS online BOOL DEFAULT false;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
ALTER TABLE "edge" DROP COLUMN IF EXISTS last_seen;
ALTER TABLE "edge" DROP COLUMN IF EXISTS online;
