-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE public."user"
  ADD COLUMN IF NOT EXISTS logged_out_at TIMESTAMPTZ;

-- +micrate StatementBegin
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'user'
      AND column_name = 'logged_out_at'
      AND data_type = 'timestamp without time zone'
  ) THEN
    ALTER TABLE public."user"
      ALTER COLUMN logged_out_at TYPE TIMESTAMPTZ
      USING logged_out_at AT TIME ZONE 'UTC';
  END IF;
END
$$;
-- +micrate StatementEnd
