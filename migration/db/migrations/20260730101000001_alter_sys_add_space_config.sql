-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "sys" ADD COLUMN IF NOT EXISTS space_config JSONB NOT NULL DEFAULT '{}'::jsonb;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "sys" DROP COLUMN IF EXISTS space_config;