-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "user" ADD COLUMN IF NOT EXISTS work_preferences jsonb DEFAULT '{}'::jsonb;
ALTER TABLE "user" ADD COLUMN IF NOT EXISTS work_overrides jsonb DEFAULT '{}'::jsonb;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "user" DROP COLUMN IF EXISTS work_preferences;
ALTER TABLE "user" DROP COLUMN IF EXISTS work_overrides;

