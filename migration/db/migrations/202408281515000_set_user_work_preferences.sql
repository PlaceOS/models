-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- Clear out the work preferences and overrides for all users
UPDATE "user" SET work_preferences = '[]'::jsonb;
UPDATE "user" SET work_overrides = '{}'::jsonb;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

-- Clear out the work preferences and overrides for all users
UPDATE "user" SET work_preferences = '[]'::jsonb
UPDATE "user" SET work_overrides = '{}'::jsonb;
