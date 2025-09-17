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
                              AND typ.typname = 'alert_severity') THEN
    CREATE TYPE alert_severity AS ENUM (
            'LOW',
            'MEDIUM',
            'HIGH',
            'CRITICAL'
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
                              AND typ.typname = 'alert_type') THEN
    CREATE TYPE alert_type AS ENUM (
            'THRESHOLD',
            'STATUS',
            'CUSTOM'
        );
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

CREATE TABLE IF NOT EXISTS "alert"(
     created_at TIMESTAMPTZ NOT NULL,
   updated_at TIMESTAMPTZ NOT NULL,
   name TEXT NOT NULL,
   description TEXT NOT NULL,
   enabled BOOLEAN NOT NULL,
   conditions JSONB NOT NULL,
   severity public.alert_severity NOT NULL DEFAULT 'MEDIUM'::public.alert_severity,
   alert_type public.alert_type NOT NULL DEFAULT 'THRESHOLD'::public.alert_type,
   check_interval INTEGER NOT NULL,
   alert_dashboard_id TEXT NOT NULL,
   id TEXT NOT NULL PRIMARY KEY,
   FOREIGN KEY (alert_dashboard_id) REFERENCES alert_dashboard(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS alert_alert_dashboard_id_index ON "alert" USING BTREE (alert_dashboard_id);
CREATE INDEX IF NOT EXISTS alert_enabled_index ON "alert" USING BTREE (enabled);
CREATE INDEX IF NOT EXISTS alert_severity_index ON "alert" USING BTREE (severity);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP TABLE IF EXISTS "alert";
DROP TYPE IF EXISTS public.alert_type;
DROP TYPE IF EXISTS public.alert_severity;
