-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE tenants ADD COLUMN IF NOT EXISTS email_domain TEXT;
 
-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE tenants DROP COLUMN email_domain;
