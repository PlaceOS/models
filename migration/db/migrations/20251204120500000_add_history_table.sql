-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

CREATE TABLE IF NOT EXISTS "history" (
  id TEXT NOT NULL PRIMARY KEY,
  type TEXT NOT NULL,
  object_id TEXT NOT NULL,
  changed_fields TEXT[] NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS history_type_index ON "history" USING BTREE (type);
CREATE INDEX IF NOT EXISTS history_object_id_index ON "history" USING BTREE (object_id);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP TABLE IF EXISTS "history";
