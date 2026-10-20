-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- Unified change history for tracked models (see `History::Tracked`).
-- Replaces the previous `history` table (changed fields only) and
-- `group_history`, whose rows are migrated with the group id as the
-- correlation id.
ALTER TABLE IF EXISTS "history" RENAME TO "history_legacy";

CREATE TABLE IF NOT EXISTS "history" (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  resource_type TEXT NOT NULL,
  resource_id TEXT NOT NULL,
  correlation_id TEXT,
  action TEXT NOT NULL,
  changed_fields TEXT[] NOT NULL DEFAULT '{}',
  -- {"field": [previous, current]}
  diff JSONB NOT NULL DEFAULT '{}'::jsonb,
  -- the full record, for deletes and approvals
  snapshot JSONB,
  -- the acting user, kept without a foreign key so the trail survives user deletion
  user_id TEXT,
  user_email TEXT,
  -- request details: app id, name, build, user agent, ip etc
  context JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS history_resource_index
  ON "history" USING BTREE (resource_type, resource_id, created_at DESC);
CREATE INDEX IF NOT EXISTS history_correlation_id_index
  ON "history" USING BTREE (correlation_id, created_at DESC)
  WHERE correlation_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS history_user_id_index
  ON "history" USING BTREE (user_id)
  WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS history_created_at_index
  ON "history" USING BTREE (created_at);

INSERT INTO "history" (
  resource_type, resource_id, correlation_id, action, changed_fields, user_id, user_email, created_at
)
SELECT
  CASE resource_type
    WHEN 'group' THEN 'groups'
    WHEN 'group_user' THEN 'group_users'
    WHEN 'group_zone' THEN 'group_zones'
    WHEN 'group_invitation' THEN 'group_invitations'
    ELSE resource_type
  END,
  resource_id,
  group_id::TEXT,
  action,
  changed_fields,
  user_id,
  email,
  created_at
FROM "group_history";

DROP TABLE IF EXISTS "group_history";

-- Calendar event (staff-api) and signage template changes
INSERT INTO "history" (resource_type, resource_id, action, changed_fields, created_at)
SELECT
  CASE type WHEN 'template' THEN 'signage_template' ELSE type END,
  resource_id,
  action,
  changed_fields,
  created_at
FROM "history_legacy";

DROP TABLE IF EXISTS "history_legacy";

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

CREATE TABLE IF NOT EXISTS "group_history"(
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    group_id UUID,
    user_id TEXT REFERENCES "user"(id) ON DELETE SET NULL,
    email TEXT NOT NULL,
    action TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id TEXT NOT NULL,
    changed_fields TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS group_history_group_id_index
    ON "group_history" USING BTREE (group_id);
CREATE INDEX IF NOT EXISTS group_history_user_id_index
    ON "group_history" USING BTREE (user_id);
CREATE INDEX IF NOT EXISTS group_history_created_at_index
    ON "group_history" USING BTREE (created_at);

INSERT INTO "group_history" (
  group_id, user_id, email, action, resource_type, resource_id, changed_fields, created_at
)
SELECT
  h.correlation_id::UUID,
  u.id,
  h.user_email,
  h.action,
  CASE h.resource_type
    WHEN 'groups' THEN 'group'
    WHEN 'group_users' THEN 'group_user'
    WHEN 'group_zones' THEN 'group_zone'
    WHEN 'group_invitations' THEN 'group_invitation'
  END,
  h.resource_id,
  h.changed_fields,
  h.created_at
FROM "history" h
LEFT JOIN "user" u ON u.id = h.user_id
WHERE h.resource_type IN ('groups', 'group_users', 'group_zones', 'group_invitations')
  AND h.user_email IS NOT NULL;

ALTER TABLE "history" RENAME TO "history_unified";

CREATE TABLE IF NOT EXISTS "history" (
  id TEXT NOT NULL PRIMARY KEY,
  type TEXT NOT NULL,
  resource_id TEXT NOT NULL,
  action TEXT NOT NULL,
  changed_fields TEXT[] NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS history_type_index ON "history" USING BTREE (type);
CREATE INDEX IF NOT EXISTS history_resource_id_index ON "history" USING BTREE (resource_id);

INSERT INTO "history" (id, type, resource_id, action, changed_fields, created_at, updated_at)
SELECT
  id::TEXT,
  CASE resource_type WHEN 'signage_template' THEN 'template' ELSE resource_type END,
  resource_id,
  action,
  changed_fields,
  created_at,
  created_at
FROM "history_unified"
WHERE resource_type = 'event'
   OR (resource_type = 'signage_template' AND action = 'updated');

DROP TABLE IF EXISTS "history_unified";
