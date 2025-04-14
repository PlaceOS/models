-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "sys" ADD COLUMN IF NOT EXISTS approval BOOLEAN DEFAULT FALSE;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "sys" DROP COLUMN IF EXISTS approval;
