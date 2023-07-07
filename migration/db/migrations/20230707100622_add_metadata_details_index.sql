-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

CREATE INDEX IF NOT EXISTS  metadata_details_index ON "metadata" USING GIN (details jsonb_path_ops);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP INDEX IF EXISTS metadata_details_index;