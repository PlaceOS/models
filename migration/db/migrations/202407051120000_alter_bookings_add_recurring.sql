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

ALTER TABLE ONLY "bookings"
    -- none, daily, weekly, monthly
    ADD COLUMN IF NOT EXISTS recurrence_type public.booking_recurrence_pattern_type DEFAULT 'NONE'::public.booking_recurrence_pattern_type,

    -- days of week it's valid (bitmask default weekdays 0b0011111)
    ADD COLUMN IF NOT EXISTS recurrence_days INTEGER DEFAULT 31,

    -- 1st, 2nd, 3rd, 4th monday of the month etc (also -1, -2 etc) for last monday of the month
    ADD COLUMN IF NOT EXISTS recurrence_nth_of_month INTEGER DEFAULT 1,

    -- gap between bookings
    ADD COLUMN IF NOT EXISTS recurrence_interval INTEGER DEFAULT 1,

    -- end date for bookings
    ADD COLUMN IF NOT EXISTS recurrence_end bigint,

    -- allow for querying times of days
    ADD COLUMN starting_time TIME GENERATED ALWAYS AS ((
      TO_TIMESTAMP(booking_start::BIGINT) AT TIME ZONE 'UTC'
    )::TIME) STORED,
    ADD COLUMN ending_time TIME GENERATED ALWAYS AS ((
      TO_TIMESTAMP(booking_end::BIGINT) AT TIME ZONE 'UTC'
    )::TIME) STORED;

CREATE INDEX idx_bookings_starting_time ON bookings (starting_time);
CREATE INDEX idx_bookings_ending_time ON bookings (ending_time);

CREATE TABLE IF NOT EXISTS "booking_instances" (
  id bigint NOT NULL,
  instance_start bigint NOT NULL,
  tenant_id bigint NOT NULL,

  booking_start bigint,
  booking_end bigint,
  checked_in boolean DEFAULT false,
  checked_in_at bigint,
  checked_out_at bigint,
  deleted_at bigint,
  deleted boolean DEFAULT false,
  history jsonb DEFAULT '[]'::jsonb,
  extension_data jsonb,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,

  PRIMARY KEY (id, instance_start)
);

ALTER TABLE ONLY "booking_instances"
    ADD CONSTRAINT booking_instances_id_fkey FOREIGN KEY (id) REFERENCES "bookings"(id) ON DELETE CASCADE,
    ADD CONSTRAINT booking_instances_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES "tenants"(id) ON DELETE CASCADE,
    -- allow for querying times of days
    ADD COLUMN starting_time TIME GENERATED ALWAYS AS ((
      TO_TIMESTAMP(booking_start::BIGINT) AT TIME ZONE 'UTC'
    )::TIME) STORED,
    ADD COLUMN ending_time TIME GENERATED ALWAYS AS ((
      TO_TIMESTAMP(booking_end::BIGINT) AT TIME ZONE 'UTC'
    )::TIME) STORED;

CREATE INDEX idx_booking_instances_starting_ending_time ON booking_instances (starting_time, ending_time);
CREATE INDEX idx_booking_instances_booking_start_end ON booking_instances USING btree (booking_start, booking_end);
CREATE INDEX idx_booking_instances_tenant_id ON booking_instances (tenant_id);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP INDEX idx_bookings_starting_time;
DROP INDEX idx_bookings_ending_time;

ALTER TABLE ONLY "bookings"
  DROP COLUMN IF EXISTS ending_time,
  DROP COLUMN IF EXISTS starting_time,
  DROP COLUMN IF EXISTS recurrence_end,
  DROP COLUMN IF EXISTS recurrence_interval,
  DROP COLUMN IF EXISTS recurrence_nth_of_month,
  DROP COLUMN IF EXISTS recurrence_days,
  DROP COLUMN IF EXISTS recurrence_type;

DROP TYPE IF EXISTS public.booking_recurrence_pattern_type;

DROP INDEX idx_booking_instances_tenant_id;
DROP INDEX idx_booking_instances_booking_start_end;
DROP INDEX idx_booking_instances_starting_ending_time;

DROP TABLE IF EXISTS "booking_instances"
