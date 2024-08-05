-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE authority
ALTER COLUMN email_domains SET DEFAULT '{}';

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
