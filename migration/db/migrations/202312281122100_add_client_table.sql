-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

CREATE TABLE IF NOT EXISTS "clients"(
   id TEXT NOT NULL PRIMARY KEY,
   name TEXT NOT NULL,
   description TEXT,
   billing_address TEXT, 
   billing_contact TEXT,
   is_management BOOLEAN NOT NULL DEFAULT FALSE,
   config JSONB NULL,
   parent_id TEXT,
   created_at TIMESTAMPTZ NOT NULL,
   updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_clients_name ON clients(name);
CREATE INDEX IF NOT EXISTS idx_clients_description ON clients(description);
CREATE INDEX IF NOT EXISTS idx_clients_config ON clients USING GIN (config jsonb_path_ops);

ALTER TABLE ONLY "clients"
    ADD CONSTRAINT clients_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES "clients"(id) ON DELETE CASCADE;

ALTER TABLE "authority" ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE "authority"
   ADD CONSTRAINT fk_authority_client
   FOREIGN KEY (client_id)
   REFERENCES clients(id)
   ON DELETE CASCADE;

ALTER TABLE "sys" ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE "sys"
   ADD CONSTRAINT fk_sys_client
   FOREIGN KEY (client_id)
   REFERENCES clients(id)
   ON DELETE CASCADE;

ALTER TABLE "mod" ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE "mod"
   ADD CONSTRAINT fk_mod_client
   FOREIGN KEY (client_id)
   REFERENCES clients(id)
   ON DELETE CASCADE;

ALTER TABLE "zone" ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE "zone"
   ADD CONSTRAINT fk_zone_client
   FOREIGN KEY (client_id)
   REFERENCES clients(id)
   ON DELETE CASCADE;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
ALTER TABLE "authority"
    DROP CONSTRAINT IF EXISTS fk_authority_client;
ALTER TABLE "authority" DROP COLUMN IF EXISTS client_id;

ALTER TABLE "sys"
    DROP CONSTRAINT IF EXISTS fk_sys_client;
ALTER TABLE "sys" DROP COLUMN IF EXISTS client_id;

ALTER TABLE "mod"
    DROP CONSTRAINT IF EXISTS fk_mod_client;
ALTER TABLE "mod" DROP COLUMN IF EXISTS client_id;

ALTER TABLE "zone"
    DROP CONSTRAINT IF EXISTS fk_zone_client;
ALTER TABLE "zone" DROP COLUMN IF EXISTS client_id;

DROP TABLE IF EXISTS "clients"