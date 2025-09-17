-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

CREATE TABLE IF NOT EXISTS "alert_dashboard"(
     created_at TIMESTAMPTZ NOT NULL,
   updated_at TIMESTAMPTZ NOT NULL,
   name TEXT NOT NULL,
   description TEXT NOT NULL,
   enabled BOOLEAN NOT NULL,
   authority_id TEXT NOT NULL,
   id TEXT NOT NULL PRIMARY KEY,
   FOREIGN KEY (authority_id) REFERENCES authority(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS alert_dashboard_authority_id_index ON "alert_dashboard" USING BTREE (authority_id);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP TABLE IF EXISTS "alert_dashboard"
