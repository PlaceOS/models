-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "user" ADD COLUMN IF NOT EXISTS login_count BIGINT DEFAULT 0;
ALTER TABLE "user" ADD COLUMN IF NOT EXISTS last_login TIMESTAMPTZ DEFAULT NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
ALTER TABLE "user" DROP COLUMN IF EXISTS login_count;
ALTER TABLE "user" DROP COLUMN IF EXISTS last_login;