-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "asset_type" ALTER COLUMN category_id DROP NOT NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "asset_type" ALTER COLUMN category_id SET NOT NULL;