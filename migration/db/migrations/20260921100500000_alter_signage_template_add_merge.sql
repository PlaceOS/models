-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "signage_template" ADD COLUMN IF NOT EXISTS merge BOOLEAN NOT NULL DEFAULT FALSE;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "signage_template" DROP COLUMN IF EXISTS merge;
