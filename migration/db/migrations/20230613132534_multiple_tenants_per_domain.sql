-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE tenants ADD COLUMN IF NOT EXISTS email_domain TEXT;
ALTER TABLE tenants DROP CONSTRAINT tenants_domain_key
 
-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE tenants DROP COLUMN email_domain;
ALTER TABLE tenants
ADD CONSTRAINT tenants_domain_key UNIQUE(domain);
