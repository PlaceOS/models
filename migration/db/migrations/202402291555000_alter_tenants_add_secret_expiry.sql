-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "tenants" ADD COLUMN IF NOT EXISTS secret_expiry TIMESTAMPTZ;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "tenants" DROP COLUMN IF EXISTS secret_expiry;
