-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
ALTER TABLE "oauth_applications" ADD COLUMN IF NOT EXISTS skip_authorization boolean DEFAULT false NOT NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
ALTER TABLE "oauth_applications" DROP COLUMN IF EXISTS skip_authorization;