-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
ALTER TABLE "storages" ADD COLUMN IF NOT EXISTS ext_filter TEXT[] NULL;
ALTER TABLE "storages" ADD COLUMN IF NOT EXISTS mime_filter TEXT[] NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
ALTER TABLE "storages" DROP COLUMN IF EXISTS ext_filter;
ALTER TABLE "storages" DROP COLUMN IF EXISTS mime_filter;