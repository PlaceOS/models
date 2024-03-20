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
                              AND typ.typname = 'booking_permission_type') THEN
    CREATE TYPE booking_permission_type AS ENUM (
            'PRIVATE',
            'OPEN',
            'PUBLIC'
        );
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS permission public.booking_permission_type DEFAULT 'PRIVATE'::public.booking_permission_type;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "bookings" DROP COLUMN IF EXISTS permission;
DROP TYPE IF EXISTS public.booking_permission_type;
