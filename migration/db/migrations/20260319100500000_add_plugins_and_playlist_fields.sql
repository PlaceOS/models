-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "playlists"
  ADD COLUMN IF NOT EXISTS play_at_period INTEGER;

ALTER TABLE "playlists"
  ADD COLUMN IF NOT EXISTS play_at_takeover BOOLEAN NOT NULL DEFAULT FALSE;

-- +micrate StatementBegin
DO
$$
BEGIN
  IF NOT EXISTS (SELECT *
                        FROM pg_type typ
                             INNER JOIN pg_namespace nsp
                                        ON nsp.oid = typ.typnamespace
                        WHERE nsp.nspname = current_schema()
                              AND typ.typname = 'signage_plugin_playback_type') THEN
    CREATE TYPE signage_plugin_playback_type AS ENUM (
            'STATIC',
            'INTERACTIVE',
            'PLAYSTHROUGH'
        );
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

CREATE TABLE IF NOT EXISTS "signage_plugin"(
  id TEXT NOT NULL PRIMARY KEY,
  authority_id TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,

  name TEXT NOT NULL,
  description TEXT,
  uri TEXT NOT NULL,
  playback_type public.signage_plugin_playback_type NOT NULL DEFAULT 'STATIC'::public.signage_plugin_playback_type,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  params JSONB NOT NULL DEFAULT '{}'::jsonb,
  defaults JSONB NOT NULL DEFAULT '{}'::jsonb,
  CHECK (jsonb_typeof(params) = 'object'),
  CHECK (jsonb_typeof(defaults) = 'object'),
  FOREIGN KEY (authority_id) REFERENCES authority(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS signage_plugin_authority_id_index ON "signage_plugin" USING BTREE (authority_id);

ALTER TABLE "playlist_items"
  ADD COLUMN IF NOT EXISTS plugin_id TEXT REFERENCES "signage_plugin"(id) ON DELETE CASCADE;

ALTER TABLE "playlist_items"
  ADD COLUMN IF NOT EXISTS plugin_params JSONB NOT NULL DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS playlist_items_plugin_id_index ON "playlist_items" USING BTREE (plugin_id);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "playlist_items" DROP COLUMN IF EXISTS plugin_params;
ALTER TABLE "playlist_items" DROP COLUMN IF EXISTS plugin_id;
DROP TABLE IF EXISTS "signage_plugin";
ALTER TABLE "playlists" DROP COLUMN IF EXISTS play_at_period;
ALTER TABLE "playlists" DROP COLUMN IF EXISTS play_at_takeover;

-- Drop the enum type
DROP TYPE IF EXISTS public.signage_plugin_playback_type;
