-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- The text/vision model a provider row uses for map editing. NULL means the
-- adapter's default for that vendor.
ALTER TABLE "signage_ai_providers" ADD COLUMN IF NOT EXISTS text_model TEXT;

-- MAP_EDIT jobs share the table with the image kinds: one vendor call each,
-- the operations land in result->'ops'.
ALTER TABLE "signage_ai_jobs" DROP CONSTRAINT IF EXISTS signage_ai_jobs_kind_check;
ALTER TABLE "signage_ai_jobs" ADD CONSTRAINT signage_ai_jobs_kind_check
  CHECK (kind IN ('GENERATE', 'EDIT', 'MAP_EDIT'));

CREATE INDEX IF NOT EXISTS signage_ai_jobs_kind_created_index
  ON "signage_ai_jobs" USING BTREE (kind, created_at);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP INDEX IF EXISTS signage_ai_jobs_kind_created_index;

ALTER TABLE "signage_ai_jobs" DROP CONSTRAINT IF EXISTS signage_ai_jobs_kind_check;
ALTER TABLE "signage_ai_jobs" ADD CONSTRAINT signage_ai_jobs_kind_check
  CHECK (kind IN ('GENERATE', 'EDIT'));

ALTER TABLE "signage_ai_providers" DROP COLUMN IF EXISTS text_model;
