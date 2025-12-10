-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "trigger" ADD COLUMN IF NOT EXISTS "any_match" boolean NOT NULL DEFAULT false;
ALTER TABLE "alert" ADD COLUMN IF NOT EXISTS "any_match" boolean NOT NULL DEFAULT false;
ALTER TABLE "sys" ADD COLUMN IF NOT EXISTS "security_groups" TEXT[] NOT NULL DEFAULT '{}';

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "sys" DROP COLUMN IF EXISTS "security_groups";
ALTER TABLE "alert" DROP COLUMN IF EXISTS "any_match";
ALTER TABLE "trigger" DROP COLUMN IF EXISTS "any_match";
