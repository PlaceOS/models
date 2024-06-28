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
                              AND typ.typname = 'booking_recurrence_pattern_type') THEN
    CREATE TYPE booking_recurrence_pattern_type AS ENUM (
            'NONE',
            'DAILY',
            'WEEKLY',
            'MONTHLY'
        );
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

-- none, daily, weekly, monthly
ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS recurrence_type public.booking_recurrence_pattern_type DEFAULT 'NONE'::public.booking_recurrence_pattern_type;

-- days of week it's valid (bitmask default weekdays 0b0011111)
ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS recurrence_days INTEGER DEFAULT 31;

-- 1st, 2nd, 3rd, 4th monday of the month etc (also -1, -2 etc) for last monday of the month
ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS recurrence_nth_of_month INTEGER DEFAULT 1;

-- gap between bookings
ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS recurrence_interval INTEGER DEFAULT 1;

-- end date for bookings
ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS recurrence_end bigint;

CREATE TABLE IF NOT EXISTS "booking_instances" (
  booking_id bigint NOT NULL,
  instance_start bigint NOT NULL,

  booking_start bigint,
  booking_end bigint,
  checked_in boolean DEFAULT false,
  checked_in_at bigint,
  checked_out_at bigint,
  deleted_at bigint,
  deleted boolean DEFAULT false,
  history jsonb DEFAULT '[]'::jsonb,
  extension_data jsonb DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL

  PRIMARY KEY (booking_id, instance_start)
)

CREATE INDEX IF NOT EXISTS booking_instances_booking_id_index ON "booking_instances" USING HASH (booking_id);

ALTER TABLE ONLY "booking_instances"
    ADD CONSTRAINT booking_instances_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES "bookings"(id) ON DELETE CASCADE;


-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "bookings" DROP COLUMN IF EXISTS recurrence_end;
ALTER TABLE "bookings" DROP COLUMN IF EXISTS recurrence_interval;
ALTER TABLE "bookings" DROP COLUMN IF EXISTS recurrence_week_of_month;
ALTER TABLE "bookings" DROP COLUMN IF EXISTS recurrence_days;
ALTER TABLE "bookings" DROP COLUMN IF EXISTS recurrence_type;
DROP TYPE IF EXISTS public.booking_recurrence_pattern_type;

DROP TABLE IF EXISTS "booking_instances"
