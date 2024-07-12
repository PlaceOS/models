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
                              AND typ.typname = 'event_metadata_permission_type') THEN
    CREATE TYPE event_metadata_permission_type AS ENUM (
            'PRIVATE',
            'OPEN',
            'PUBLIC'
        );
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

ALTER TABLE "event_metadatas" ADD COLUMN IF NOT EXISTS permission public.event_metadata_permission_type DEFAULT 'PRIVATE'::public.event_metadata_permission_type;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "event_metadatas" DROP COLUMN IF EXISTS permission;
DROP TYPE IF EXISTS public.event_metadata_permission_type;
