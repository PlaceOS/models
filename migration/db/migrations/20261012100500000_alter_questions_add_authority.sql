-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- questions belong to an authority. Nullable so existing questions can be adopted by staff-api,
-- the model requires it for new and updated questions
ALTER TABLE "questions" ADD COLUMN IF NOT EXISTS authority_id TEXT;
CREATE INDEX IF NOT EXISTS index_questions_authority_id ON "questions" USING btree (authority_id);
ALTER TABLE "questions" DROP CONSTRAINT IF EXISTS questions_authority_id_fkey;
ALTER TABLE "questions"
  ADD CONSTRAINT questions_authority_id_fkey FOREIGN KEY (authority_id)
  REFERENCES authority(id) ON DELETE CASCADE;

-- the version of a question that this one replaced, when an answered question was changed
ALTER TABLE "questions" ADD COLUMN IF NOT EXISTS previous_question_id BIGINT;
CREATE INDEX IF NOT EXISTS index_questions_previous_question_id ON "questions" USING btree (previous_question_id);
ALTER TABLE "questions" DROP CONSTRAINT IF EXISTS questions_previous_question_id_fkey;
ALTER TABLE "questions"
  ADD CONSTRAINT questions_previous_question_id_fkey FOREIGN KEY (previous_question_id)
  REFERENCES questions(id) ON DELETE SET NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "questions" DROP CONSTRAINT IF EXISTS questions_previous_question_id_fkey;
DROP INDEX IF EXISTS index_questions_previous_question_id;
ALTER TABLE "questions" DROP COLUMN IF EXISTS previous_question_id;
ALTER TABLE "questions" DROP CONSTRAINT IF EXISTS questions_authority_id_fkey;
DROP INDEX IF EXISTS index_questions_authority_id;
ALTER TABLE "questions" DROP COLUMN IF EXISTS authority_id;
