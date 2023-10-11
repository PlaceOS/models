-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
ALTER TABLE "asset_category"
    DROP CONSTRAINT IF EXISTS asset_category_parent_category_id_fkey;

ALTER TABLE "asset_type"
    DROP CONSTRAINT IF EXISTS asset_type_category_id_fkey;

ALTER TABLE "asset_category"
    ADD CONSTRAINT asset_category_parent_category_id_fkey FOREIGN KEY (parent_category_id) REFERENCES "asset_category"(id) ON DELETE SET NULL;

ALTER TABLE "asset_type"
    ADD CONSTRAINT asset_type_category_id_fkey FOREIGN KEY (category_id) REFERENCES "asset_category"(id) ON DELETE SET NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
ALTER TABLE "asset_category"
    DROP CONSTRAINT IF EXISTS asset_category_parent_category_id_fkey;

ALTER TABLE "asset_type"
    DROP CONSTRAINT IF EXISTS asset_type_category_id_fkey;