-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- +micrate StatementBegin
DO
$$
BEGIN
  IF NOT EXISTS (SELECT *
                        FROM pg_type typ
                             INNER JOIN pg_namespace nsp
                                        ON nsp.oid = typ.typnamespace
                        WHERE nsp.nspname = current_schema()
                              AND typ.typname = 'playlist_orientation_type') THEN
    CREATE TYPE playlist_orientation_type AS ENUM (
            'UNSPECIFIED',
            'LANDSCAPE',
            'PORTRAIT',
            'SQUARE'
        );
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

-- +micrate StatementBegin
DO
$$
BEGIN
  IF NOT EXISTS (SELECT *
                        FROM pg_type typ
                             INNER JOIN pg_namespace nsp
                                        ON nsp.oid = typ.typnamespace
                        WHERE nsp.nspname = current_schema()
                              AND typ.typname = 'playlist_item_media_type') THEN
    CREATE TYPE playlist_item_media_type AS ENUM (
            'IMAGE',
            'VIDEO',
            'PLUGIN',
            'WEBPAGE',
            'EXTERNAL_IMAGE'
        );
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

-- Update the control system table
ALTER TABLE "sys" ADD COLUMN IF NOT EXISTS orientation public.playlist_orientation_type DEFAULT 'UNSPECIFIED'::public.playlist_orientation_type;
ALTER TABLE "sys" ADD COLUMN IF NOT EXISTS playlists TEXT[] DEFAULT '{}'::TEXT[];
ALTER TABLE "sys" ADD COLUMN IF NOT EXISTS signage BOOL DEFAULT false;

-- improve the performance of queries that use the @> (contains), <@ (is contained by), and && (overlap) operators to search within arrays.
CREATE INDEX sys_playlists_idx ON sys USING GIN (playlists);

-- Update the zones table
ALTER TABLE "zone" ADD COLUMN IF NOT EXISTS playlists TEXT[] DEFAULT '{}'::TEXT[];

CREATE INDEX zone_playlists_idx ON zone USING GIN (playlists);

-- Update the trigger instance table

ALTER TABLE "trig" ADD COLUMN IF NOT EXISTS playlists TEXT[] DEFAULT '{}'::TEXT[];

CREATE INDEX trig_playlists_idx ON zone USING GIN (playlists);

-- ===
-- Add Playlist table
-- ===

CREATE TABLE IF NOT EXISTS "playlists" (
  id TEXT NOT NULL PRIMARY KEY,
  authority_id TEXT NOT NULL REFERENCES "authority"(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  orientation public.playlist_orientation_type DEFAULT 'PORTRAIT'::public.playlist_orientation_type,
  play_count BIGINT NOT NULL DEFAULT 0,
  play_through_count BIGINT NOT NULL DEFAULT 0,
  default_animation INT NOT NULL DEFAULT 0,
  random BOOL NOT NULL DEFAULT false,
  enabled BOOL NOT NULL DEFAULT true,
  default_duration INT NOT NULL DEFAULT 10000,
  valid_from BIGINT,
  valid_until BIGINT,
  play_at BIGINT,
  play_cron TEXT,
  play_hours TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS playlists_authority_id_index ON "playlists" USING HASH (authority_id);

-- ===
-- Add Playlist Revision table
-- ===

CREATE TABLE IF NOT EXISTS "playlist_revisions" (
  id TEXT NOT NULL PRIMARY KEY,

  user_id TEXT NOT NULL,
  user_email TEXT NOT NULL,
  user_name TEXT NOT NULL,

  items TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
  playlist_id TEXT NOT NULL REFERENCES "playlists"(id) ON DELETE CASCADE,

  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX playlist_revisions_items_idx ON playlist_revisions USING GIN (items);

-- ===
-- Add Playlist Item table
-- ===

CREATE TABLE IF NOT EXISTS "playlist_items" (
  id TEXT NOT NULL PRIMARY KEY,
  authority_id TEXT NOT NULL REFERENCES "authority"(id) ON DELETE CASCADE,

  name TEXT NOT NULL,
  description TEXT,

  start_time INT NOT NULL DEFAULT 0,
  play_time INT NOT NULL DEFAULT 0,
  animation INT,

  media_type public.playlist_item_media_type NOT NULL,
  orientation public.playlist_orientation_type DEFAULT 'UNSPECIFIED'::public.playlist_orientation_type,

  media_uri TEXT,
  media_id TEXT REFERENCES "uploads"(id) ON DELETE CASCADE,
  thumbnail_id TEXT REFERENCES "uploads"(id) ON DELETE SET NULL,

  play_count BIGINT NOT NULL DEFAULT 0,
  valid_from BIGINT,
  valid_until BIGINT,

  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS playlist_items_authority_id_index ON "playlist_items" USING HASH (authority_id);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP INDEX IF EXISTS playlists_authority_id_index;
DROP INDEX IF EXISTS playlist_revisions_items_idx;
DROP INDEX IF EXISTS playlist_items_authority_id_index;

DROP TABLE IF EXISTS "playlist_items";
DROP TABLE IF EXISTS "playlist_revisions";
DROP TABLE IF EXISTS "playlists";

DROP INDEX IF EXISTS sys_playlists_idx;
DROP INDEX IF EXISTS zone_playlists_idx;

ALTER TABLE "sys" DROP COLUMN IF EXISTS orientation;
ALTER TABLE "sys" DROP COLUMN IF EXISTS playlists;
ALTER TABLE "sys" DROP COLUMN IF EXISTS signage;

ALTER TABLE "zone" DROP COLUMN IF EXISTS playlists;

DROP TYPE IF EXISTS public.playlist_orientation_type;
DROP TYPE IF EXISTS public.playlist_item_media_type;
