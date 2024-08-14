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
                              AND typ.typname = 'booking_induction_type') THEN
    CREATE TYPE booking_induction_type AS ENUM (
            'TENTATIVE',
            'ACCEPTED',
            'DECLINED'
        );
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

-- Add the new column
ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS induction_new public.booking_induction_type DEFAULT 'TENTATIVE'::public.booking_induction_type;

-- Migrate data
UPDATE bookings
SET induction_new = CASE
    WHEN induction = true THEN 'ACCEPTED'::public.booking_induction_type
    ELSE 'TENTATIVE'::public.booking_induction_type
END;

-- Drop the old column and rename the new column
ALTER TABLE bookings DROP COLUMN induction;
ALTER TABLE bookings RENAME COLUMN induction_new TO induction;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

-- Add a temporary boolean column
ALTER TABLE bookings ADD COLUMN induction_old boolean DEFAULT false;

-- Migrate data back to boolean
UPDATE bookings
SET induction_old = CASE
    WHEN induction = 'ACCEPTED' THEN true
    ELSE false
END;

-- Drop the enum column
ALTER TABLE bookings DROP COLUMN induction;

-- Rename the boolean column back to original name
ALTER TABLE bookings RENAME COLUMN induction_old TO induction;

-- Drop the enum type
DROP TYPE IF EXISTS public.booking_induction_type;
