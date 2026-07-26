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
                              AND typ.typname = 'signage_plugin_plugin_type') THEN
    CREATE TYPE signage_plugin_plugin_type AS ENUM (
            'PLUGIN',
            'WIDGET'
        );
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

ALTER TABLE "signage_plugin"
  ADD COLUMN IF NOT EXISTS plugin_type public.signage_plugin_plugin_type NOT NULL DEFAULT 'PLUGIN'::public.signage_plugin_plugin_type;

-- templates position widget plugins over signage displays
CREATE TABLE IF NOT EXISTS "signage_template"(
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  authority_id TEXT NOT NULL,
  background_item_id TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,

  name TEXT NOT NULL,
  description TEXT,
  tags TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
  layouts JSONB NOT NULL DEFAULT '[]'::jsonb,
  full_screen_takeover BOOLEAN NOT NULL DEFAULT FALSE,

  approval_requested BOOLEAN NOT NULL DEFAULT FALSE,
  requested_by_id TEXT,
  approved BOOLEAN NOT NULL DEFAULT FALSE,
  approved_by_id TEXT,
  approved_by_name TEXT,
  approved_by_email TEXT,

  -- set on draft rows: references the approved parent template this row
  -- was copied from; drafts are removed when the parent is deleted
  live_template_id UUID,

  CHECK (jsonb_typeof(layouts) = 'array'),
  FOREIGN KEY (authority_id) REFERENCES authority(id) ON DELETE CASCADE,
  FOREIGN KEY (background_item_id) REFERENCES playlist_items(id) ON DELETE SET NULL,
  FOREIGN KEY (requested_by_id) REFERENCES "user"(id) ON DELETE SET NULL,
  FOREIGN KEY (approved_by_id) REFERENCES "user"(id) ON DELETE SET NULL,
  FOREIGN KEY (live_template_id) REFERENCES signage_template(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS signage_template_authority_id_index ON "signage_template" USING BTREE (authority_id);
CREATE INDEX IF NOT EXISTS signage_template_background_item_id_index ON "signage_template" USING BTREE (background_item_id);
CREATE INDEX IF NOT EXISTS signage_template_live_template_id_index ON "signage_template" USING BTREE (live_template_id);
CREATE INDEX IF NOT EXISTS signage_template_tags_index ON "signage_template" USING GIN (tags);

-- junction attaching templates to control systems or zones (exactly one),
-- each row optionally scoped by a schedule. A schedule-less row is the
-- default template for the pairing (at most one, enforced by the partial
-- unique indexes).
CREATE TABLE IF NOT EXISTS "system_templates"(
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  control_system_id TEXT,
  zone_id TEXT,
  template_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,

  schedule JSONB,
  CHECK (schedule IS NULL OR jsonb_typeof(schedule) = 'object'),
  CHECK (num_nonnulls(control_system_id, zone_id) = 1),
  FOREIGN KEY (control_system_id) REFERENCES sys(id) ON DELETE CASCADE,
  FOREIGN KEY (zone_id) REFERENCES zone(id) ON DELETE CASCADE,
  FOREIGN KEY (template_id) REFERENCES signage_template(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS system_templates_control_system_id_index ON "system_templates" USING BTREE (control_system_id);
CREATE INDEX IF NOT EXISTS system_templates_zone_id_index ON "system_templates" USING BTREE (zone_id);
CREATE INDEX IF NOT EXISTS system_templates_template_id_index ON "system_templates" USING BTREE (template_id);
CREATE UNIQUE INDEX IF NOT EXISTS system_templates_system_default_unique ON "system_templates" (control_system_id, template_id) WHERE schedule IS NULL AND control_system_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS system_templates_zone_default_unique ON "system_templates" (zone_id, template_id) WHERE schedule IS NULL AND zone_id IS NOT NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP TABLE IF EXISTS "system_templates";
DROP TABLE IF EXISTS "signage_template";
ALTER TABLE "signage_plugin" DROP COLUMN IF EXISTS plugin_type;

-- Drop the enum type
DROP TYPE IF EXISTS public.signage_plugin_plugin_type;
