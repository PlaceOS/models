-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE asset ADD COLUMN IF NOT EXISTS barcode TEXT;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE asset DROP COLUMN barcode;
