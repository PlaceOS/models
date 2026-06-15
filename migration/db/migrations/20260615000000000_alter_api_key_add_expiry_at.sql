-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE api_key ADD COLUMN expires_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS api_key_expires_at_index ON "api_key" USING BTREE (expires_at);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE api_key DROP COLUMN IF EXISTS expires_at;
