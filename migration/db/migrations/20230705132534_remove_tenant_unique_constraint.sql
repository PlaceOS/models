-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE tenants DROP CONSTRAINT IF EXISTS unique_domain;
  
-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
