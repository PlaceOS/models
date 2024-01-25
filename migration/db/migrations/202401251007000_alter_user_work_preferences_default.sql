-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "user" ALTER COLUMN work_preferences SET DEFAULT '[]'::jsonb;
UPDATE "user" SET work_preferences = '[]'::jsonb WHERE work_preferences = '{}'::jsonb;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "user" ALTER COLUMN work_preferences SET DEFAULT '{}'::jsonb;
UPDATE "user" SET work_preferences = '{}'::jsonb WHERE work_preferences = '[]'::jsonb;
