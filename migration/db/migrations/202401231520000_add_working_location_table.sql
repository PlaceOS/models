-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

CREATE TABLE IF NOT EXISTS "working_location" (
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  start_time bigint NOT NULL,
  end_time bigint NOT NULL,
  location text NOT NULL DEFAULT '',
  user_id text NOT NULL,
  id text NOT NULL PRIMARY KEY
);

CREATE INDEX IF NOT EXISTS working_location_user_id_idx ON "working_location" USING btree (user_id);

ALTER TABLE "user" ADD COLUMN IF NOT EXISTS working_location_preference jsonb DEFAULT '{}'::jsonb;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "user" DROP COLUMN IF EXISTS working_location_preference;
DROP TABLE IF EXISTS "working_location"
