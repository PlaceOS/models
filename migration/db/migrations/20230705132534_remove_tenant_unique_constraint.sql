-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

DROP INDEX concurrently IF EXISTS tenants_domain;
DROP INDEX IF EXISTS tenants_domain;
  
-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
