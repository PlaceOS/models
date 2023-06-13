-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE tenants ADD COLUMN IF NOT EXISTS email_domain TEXT;
ALTER TABLE tenants DROP CONSTRAINT tenants_domain_key;
DROP INDEX index_tenants_domain;
CREATE INDEX index_tenants_domain ON tenants (domain);
 
-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE tenants DROP COLUMN email_domain;
ALTER TABLE tenants
ADD CONSTRAINT tenants_domain_key UNIQUE(domain);
DROP INDEX index_tenants_domain;
CREATE UNIQUE INDEX IF NOT EXISTS index_tenants_domain ON "tenants" USING btree (domain);
