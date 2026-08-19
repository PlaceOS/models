-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- MERGE-TIME CHECK: micrate refuses out-of-order version ids. If a later-dated
-- migration lands on master before this merges, renumber this file above it.

-- ---------------------------------------------------------------------------
-- PPT-526 Stage 3: the authorization `grants` table (Zanzibar-lite tuple).
--
-- A grant gives a user a permission bitmask over a scope, which is one of a
-- Partner, a Client, or an Authority. Authorization walks UP from the touched
-- resource (authority -> its client -> that client's partner) and ORs every
-- live grant found on the chain, so a single grant at partner scope applies to
-- all of that partner's clients, current and future (decision b, 2026-08-19).
--
-- `scope_id` is polymorphic (a partner/client UUID as text, or an authority
-- TEXT id), so it carries no DB foreign key. A grant naming a deleted scope is
-- inert: resolution walks up from live resources and never matches it, so
-- orphan grants are harmless and can be swept lazily. The one real FK is
-- user_id (CASCADE) so a user's grants vanish with the user.
--
-- `permissions` is the existing `PlaceOS::Model::Permissions` flags enum stored
-- as an Int32 bitmask (decision a) — the same column shape as group_users.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "grants"(
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    user_id TEXT NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
    scope_type TEXT NOT NULL CHECK (scope_type IN ('partner', 'client', 'authority')),
    scope_id TEXT NOT NULL,
    permissions INTEGER NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ,
    granted_by TEXT,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

-- One grant per (user, scope) — a re-grant updates the existing row's bitmask
-- and expiry rather than stacking duplicates.
CREATE UNIQUE INDEX IF NOT EXISTS grants_user_scope_unique
    ON "grants" USING BTREE (user_id, scope_type, scope_id);

-- "what can this user reach" (resolution walks per user).
CREATE INDEX IF NOT EXISTS grants_user_id_index
    ON "grants" USING BTREE (user_id);

-- "who can reach this scope" (partner/client admin console, audit).
CREATE INDEX IF NOT EXISTS grants_scope_index
    ON "grants" USING BTREE (scope_type, scope_id);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP INDEX IF EXISTS grants_scope_index;
DROP INDEX IF EXISTS grants_user_id_index;
DROP INDEX IF EXISTS grants_user_scope_unique;
DROP TABLE IF EXISTS "grants";
