-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

CREATE TABLE IF NOT EXISTS "working_from_home" (
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  start_time bigint NOT NULL,
  end_time bigint NOT NULL,
  user_id text NOT NULL,
  id TEXT NOT NULL PRIMARY KEY
);

CREATE INDEX IF NOT EXISTS working_from_home_user_id_idx ON "working_from_home" USING btree (user_id);

ALTER TABLE "user" ADD COLUMN IF NOT EXISTS wfh_preference jsonb DEFAULT '{}'::jsonb;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "user" DROP COLUMN IF EXISTS wfh_preference;
DROP TABLE IF EXISTS "working_from_home"
