-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- deleting a purchase order clears it from its assets instead of deleting them
ALTER TABLE "asset" DROP CONSTRAINT IF EXISTS asset_purchase_order_id_fkey;
ALTER TABLE "asset"
  ADD CONSTRAINT asset_purchase_order_id_fkey FOREIGN KEY (purchase_order_id)
  REFERENCES "asset_purchase_order"(id) ON DELETE SET NULL;

-- purchase orders belong to an authority. They aren't in production use yet, so existing rows
-- (which have no authority) are removed rather than adopted; their assets are kept
DELETE FROM "asset_purchase_order";

ALTER TABLE "asset_purchase_order" ADD COLUMN IF NOT EXISTS authority_id TEXT NOT NULL;
CREATE INDEX IF NOT EXISTS index_asset_purchase_order_authority_id ON "asset_purchase_order" USING btree (authority_id);
ALTER TABLE "asset_purchase_order" DROP CONSTRAINT IF EXISTS asset_purchase_order_authority_id_fkey;
ALTER TABLE "asset_purchase_order"
  ADD CONSTRAINT asset_purchase_order_authority_id_fkey FOREIGN KEY (authority_id)
  REFERENCES authority(id) ON DELETE CASCADE;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
-- (the purchase orders removed by Up are not restored)

ALTER TABLE "asset_purchase_order" DROP CONSTRAINT IF EXISTS asset_purchase_order_authority_id_fkey;
DROP INDEX IF EXISTS index_asset_purchase_order_authority_id;
ALTER TABLE "asset_purchase_order" DROP COLUMN IF EXISTS authority_id;

ALTER TABLE "asset" DROP CONSTRAINT IF EXISTS asset_purchase_order_id_fkey;
ALTER TABLE "asset"
  ADD CONSTRAINT asset_purchase_order_id_fkey FOREIGN KEY (purchase_order_id)
  REFERENCES "asset_purchase_order"(id) ON DELETE CASCADE;
