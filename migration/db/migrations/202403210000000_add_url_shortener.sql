-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

CREATE TABLE IF NOT EXISTS "shortener" (
  id TEXT NOT NULL PRIMARY KEY,
  authority_id TEXT NOT NULL REFERENCES "authority"(id) ON DELETE CASCADE,

  name TEXT NOT NULL,
  uri TEXT NOT NULL,
  description TEXT,

  user_id TEXT NOT NULL,
  user_email TEXT NOT NULL,
  user_name TEXT NOT NULL,

  redirect_count BIGINT NOT NULL DEFAULT 0,
  enabled BOOL NOT NULL DEFAULT true,
  valid_from BIGINT,
  valid_until BIGINT,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP TABLE IF EXISTS "shortener";
