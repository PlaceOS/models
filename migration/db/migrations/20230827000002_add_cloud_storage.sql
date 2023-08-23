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
                              AND typ.typname = 'file_storage_type') THEN
    CREATE TYPE file_storage_type AS ENUM (
            'S3',
            'AZURE',
            'GOOGLE'
        );
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

CREATE TABLE IF NOT EXISTS "storages" (
   id TEXT NOT NULL PRIMARY KEY,
   storage_type public.file_storage_type DEFAULT 'S3'::public.file_storage_type,
   bucket_name TEXT NOT NULL,
   region TEXT,
   access_key TEXT NOT NULL,
   access_secret TEXT NOT NULL,
   authority_id TEXT,
   endpoint TEXT,
   created_at TIMESTAMPTZ NOT NULL,
   updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS storages_authority_id_index ON "storages" USING BTREE (authority_id);


-- +micrate StatementBegin
DO
$$
BEGIN
  IF NOT EXISTS (SELECT *
                        FROM pg_type typ
                             INNER JOIN pg_namespace nsp
                                        ON nsp.oid = typ.typnamespace
                        WHERE nsp.nspname = current_schema()
                              AND typ.typname = 'file_permission_type') THEN
    CREATE TYPE file_permission_type AS ENUM (
            'NONE',
            'ADMIN',
            'SUPPORT'
        );
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

CREATE TABLE IF NOT EXISTS "uploads" (
    id TEXT PRIMARY KEY,
    storage_id TEXT REFERENCES "storages"(id) ON DELETE CASCADE,
    uploaded_by TEXT NOT NULL,
    uploaded_email TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_size bigint NOT NULL,
    file_path TEXT,
    object_key TEXT NOT NULL,
    file_md5 TEXT NOT NULL,
    public boolean DEFAULT false,
    permissions public.file_permission_type DEFAULT 'NONE'::public.file_permission_type,
    object_options JSONB DEFAULT '{}'::jsonb,
    resumable_id TEXT,
    resumable boolean DEFAULT false,   
    part_list INTEGER[],
    part_data JSONB DEFAULT '{}'::jsonb,
    upload_complete boolean DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);


CREATE INDEX IF NOT EXISTS uploads_uploaded_by_index ON "uploads" USING BTREE (uploaded_by);
CREATE INDEX IF NOT EXISTS uploads_uploaded_email_index ON "uploads" USING BTREE (uploaded_email);


-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP TABLE IF EXISTS "uploads";
DROP TYPE IF EXISTS public.file_permission_type;
DROP TABLE IF EXISTS "storages";
DROP TYPE IF EXISTS public.file_storage_type