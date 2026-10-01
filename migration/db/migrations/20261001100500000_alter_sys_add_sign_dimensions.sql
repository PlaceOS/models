-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "sys" ADD COLUMN IF NOT EXISTS sign_height INTEGER;
ALTER TABLE "sys" ADD COLUMN IF NOT EXISTS sign_width INTEGER;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "sys" DROP COLUMN IF EXISTS sign_height;
ALTER TABLE "sys" DROP COLUMN IF EXISTS sign_width;
