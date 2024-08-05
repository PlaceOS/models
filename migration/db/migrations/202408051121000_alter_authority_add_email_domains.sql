-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "authority" ADD COLUMN IF NOT EXISTS email_domains TEXT[];

CREATE INDEX IF NOT EXISTS authority_email_domains_index ON "authority" USING GIN (email_domains);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "authority" DROP COLUMN IF EXISTS email_domains;