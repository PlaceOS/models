-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "zone" DROP COLUMN IF EXISTS auto_release;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "zone" ADD COLUMN IF NOT EXISTS auto_release jsonb DEFAULT '{}'::jsonb;
