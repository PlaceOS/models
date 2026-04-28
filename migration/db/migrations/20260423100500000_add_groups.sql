-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- ---------------------------------------------------------------------------
-- Groups: authority-wide tree (org hierarchy). A single root per authority is
-- enforced by a partial unique index. The `subsystems` text array names every
-- subsystem (signage, events, parking, ...) that a group participates in;
-- subsystem-scoped permission queries filter on `'<code>' = ANY(subsystems)`.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "groups"(
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    authority_id TEXT NOT NULL REFERENCES "authority"(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES "groups"(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    subsystems TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS groups_authority_id_index
    ON "groups" USING BTREE (authority_id);
CREATE INDEX IF NOT EXISTS groups_parent_id_index
    ON "groups" USING BTREE (parent_id);
-- One root per authority
CREATE UNIQUE INDEX IF NOT EXISTS groups_authority_single_root
    ON "groups" (authority_id) WHERE parent_id IS NULL;
-- GIN index supports `'subsystem' = ANY(subsystems)` lookups efficiently.
CREATE INDEX IF NOT EXISTS groups_subsystems_index
    ON "groups" USING GIN (subsystems);


-- ---------------------------------------------------------------------------
-- DoorkeeperApplication.subsystems: same `TEXT[]` shape as `groups.subsystems`.
-- An OAuth client is associated with one or more subsystems — callers
-- authenticating via that client are resolved against those subsystems'
-- group permissions.
-- ---------------------------------------------------------------------------
ALTER TABLE "oauth_applications"
    ADD COLUMN IF NOT EXISTS subsystems TEXT[] NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS oauth_applications_subsystems_index
    ON "oauth_applications" USING GIN (subsystems);


-- ---------------------------------------------------------------------------
-- GroupUsers: junction between users and groups, with a permission bitmask.
-- Composite PK (user_id, group_id).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "group_users"(
    user_id TEXT NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES "groups"(id) ON DELETE CASCADE,
    permissions INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (user_id, group_id)
);

CREATE INDEX IF NOT EXISTS group_users_group_id_index
    ON "group_users" USING BTREE (group_id);


-- ---------------------------------------------------------------------------
-- GroupZones: junction between groups and zones, with a permission bitmask
-- and a `deny` flag. A deny row removes access that would otherwise be
-- inherited from an ancestor zone. Composite PK (group_id, zone_id).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "group_zones"(
    group_id UUID NOT NULL REFERENCES "groups"(id) ON DELETE CASCADE,
    zone_id TEXT NOT NULL REFERENCES "zone"(id) ON DELETE CASCADE,
    permissions INTEGER NOT NULL DEFAULT 0,
    deny BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (group_id, zone_id)
);

CREATE INDEX IF NOT EXISTS group_zones_zone_id_index
    ON "group_zones" USING BTREE (zone_id);


-- ---------------------------------------------------------------------------
-- GroupInvitations: grants access to a user not yet in the system (or external)
-- via a shared secret. Plaintext secret is generated + returned once at
-- creation time; only a SHA256 digest is stored. Optional expiry.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "group_invitations"(
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    group_id UUID NOT NULL REFERENCES "groups"(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    secret_digest TEXT NOT NULL,
    permissions INTEGER NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS group_invitations_group_id_index
    ON "group_invitations" USING BTREE (group_id);
CREATE INDEX IF NOT EXISTS group_invitations_email_index
    ON "group_invitations" USING BTREE (email);
CREATE UNIQUE INDEX IF NOT EXISTS group_invitations_secret_digest_unique
    ON "group_invitations" (secret_digest);


-- ---------------------------------------------------------------------------
-- GroupHistory: audit trail for group-related changes. Written in the same
-- transaction as the triggering save (after_save / after_destroy callbacks).
--
-- user_id is the actor. When the actor user is later deleted, user_id is
-- set to NULL but `email` is preserved so the audit trail stays readable.
-- ---------------------------------------------------------------------------
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


-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP TABLE IF EXISTS "group_history";
DROP TABLE IF EXISTS "group_invitations";
DROP TABLE IF EXISTS "group_zones";
DROP TABLE IF EXISTS "group_users";
DROP TABLE IF EXISTS "groups";

DROP INDEX IF EXISTS oauth_applications_subsystems_index;
ALTER TABLE "oauth_applications" DROP COLUMN IF EXISTS subsystems;
