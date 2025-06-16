-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE uploads
  ADD COLUMN cache_etag TEXT,
  ADD COLUMN cache_modified TIMESTAMPTZ;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE uploads
  DROP COLUMN cache_etag,
  DROP COLUMN cache_modified;
