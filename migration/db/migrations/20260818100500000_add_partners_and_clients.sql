-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- MERGE-TIME CHECK: micrate refuses out-of-order version ids (see models#323).
-- If any later-dated migration lands on master before this merges, renumber
-- this file AND 20260818100600000 above it (preserving schema-before-backfill
-- order). Safe: neither has been applied anywhere and the backfill is
-- idempotent.

-- ---------------------------------------------------------------------------
-- PPT-526: the Partner → Client → Authority(domain) hierarchy.
--
-- partners: integrators/resellers (e.g. NTT). `management = true` marks the
-- platform operator's own organisation (PlaceOS staff) — the "management
-- client" concept from the ticket, done at the partner level. `parent_id`
-- reserves a 2-tier channel (distributor → reseller) without any UI or
-- enforcement yet.
--
-- clients: the customer organisation (e.g. UCLA, Acadian). `partner_id` NULL
-- means client-owned (self-managed, no integrator). `payer` records who is
-- invoiced: 'partner' (integrator pays us and re-bills, the default channel
-- model) or 'client' (direct). A client without a partner can only pay for
-- itself — enforced by CHECK.
--
-- Every delete path is RESTRICT: removing a partner/client must go through an
-- orchestrated teardown (the PPT-1203 pattern), never a silent DB cascade —
-- model-level cleanup callbacks do not fire on DB cascades.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "partners"(
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    management BOOLEAN NOT NULL DEFAULT false,
    parent_id UUID REFERENCES "partners"(id) ON DELETE RESTRICT,
    config JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS partners_name_unique
    ON "partners" USING BTREE (name);
CREATE INDEX IF NOT EXISTS partners_parent_id_index
    ON "partners" USING BTREE (parent_id);

CREATE TABLE IF NOT EXISTS "clients"(
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    partner_id UUID REFERENCES "partners"(id) ON DELETE RESTRICT,
    payer TEXT NOT NULL DEFAULT 'partner'
        CHECK (payer IN ('partner', 'client')),
    config JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT clients_payer_requires_partner
        CHECK (partner_id IS NOT NULL OR payer = 'client')
);

-- Client names are unique within a partner's book of business, and unique
-- among client-owned clients. Two partial indexes because UNIQUE treats
-- NULLs as distinct — a plain UNIQUE (partner_id, name) would let every
-- client-owned client share a name.
CREATE UNIQUE INDEX IF NOT EXISTS clients_name_unique_per_partner
    ON "clients" USING BTREE (partner_id, name) WHERE partner_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS clients_name_unique_owned
    ON "clients" USING BTREE (name) WHERE partner_id IS NULL;
CREATE INDEX IF NOT EXISTS clients_partner_id_index
    ON "clients" USING BTREE (partner_id);

-- ---------------------------------------------------------------------------
-- Authority → Client ownership. Nullable at the DB level for backwards
-- compatibility (init seeds authorities before any client exists); the
-- provisioning flow and backfill populate it. RESTRICT so a client cannot be
-- deleted while it still owns domains.
-- ---------------------------------------------------------------------------
ALTER TABLE "authority"
    ADD COLUMN IF NOT EXISTS client_id UUID;

ALTER TABLE ONLY "authority"
    DROP CONSTRAINT IF EXISTS authority_client_id_fkey;
ALTER TABLE ONLY "authority"
    ADD CONSTRAINT authority_client_id_fkey
        FOREIGN KEY (client_id) REFERENCES "clients"(id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS authority_client_id_index
    ON "authority" USING BTREE (client_id);

-- The domain column has only ever had model-level uniqueness (a plain BTREE
-- index) — a concurrent-signup race can create duplicate authorities. Make it
-- a hard guarantee; self-service signup depends on it.
--
-- Quarantine first: exact-duplicate domains left behind by that race would
-- make the unique index unbuildable and (because micrate autocommits each
-- statement) leave this migration half-applied. Keep the oldest row per
-- domain and rename the rest so they stop answering for the domain —
-- find_by_domain picks an arbitrary row across duplicates today, so this
-- cannot break a reliably-working login. Idempotent: renamed rows no longer
-- collide. Renamed rows are for an operator to merge or delete.
UPDATE "authority" a
SET domain = a.domain || '.duplicate.' || a.id
WHERE EXISTS (
    SELECT 1 FROM "authority" b
    WHERE b.domain = a.domain
      AND (b.created_at, b.id) < (a.created_at, a.id)
);

CREATE UNIQUE INDEX IF NOT EXISTS authority_domain_unique
    ON "authority" USING BTREE (domain);

-- ---------------------------------------------------------------------------
-- Client ownership columns on the (previously cluster-global) control plane.
-- Nullable: populated by the backfill migration where inference is
-- unambiguous, and by the provisioning flow for everything new. Query-path
-- enforcement is phased in separately (rest-api); these columns are the
-- ground truth it will filter on.
-- ---------------------------------------------------------------------------
ALTER TABLE "zone"    ADD COLUMN IF NOT EXISTS client_id UUID;
ALTER TABLE "sys"     ADD COLUMN IF NOT EXISTS client_id UUID;
ALTER TABLE "mod"     ADD COLUMN IF NOT EXISTS client_id UUID;
ALTER TABLE "trigger" ADD COLUMN IF NOT EXISTS client_id UUID;
ALTER TABLE "edge"    ADD COLUMN IF NOT EXISTS client_id UUID;
ALTER TABLE "broker"  ADD COLUMN IF NOT EXISTS client_id UUID;

ALTER TABLE ONLY "zone"
    DROP CONSTRAINT IF EXISTS zone_client_id_fkey;
ALTER TABLE ONLY "zone"
    ADD CONSTRAINT zone_client_id_fkey
        FOREIGN KEY (client_id) REFERENCES "clients"(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "sys"
    DROP CONSTRAINT IF EXISTS sys_client_id_fkey;
ALTER TABLE ONLY "sys"
    ADD CONSTRAINT sys_client_id_fkey
        FOREIGN KEY (client_id) REFERENCES "clients"(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "mod"
    DROP CONSTRAINT IF EXISTS mod_client_id_fkey;
ALTER TABLE ONLY "mod"
    ADD CONSTRAINT mod_client_id_fkey
        FOREIGN KEY (client_id) REFERENCES "clients"(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "trigger"
    DROP CONSTRAINT IF EXISTS trigger_client_id_fkey;
ALTER TABLE ONLY "trigger"
    ADD CONSTRAINT trigger_client_id_fkey
        FOREIGN KEY (client_id) REFERENCES "clients"(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "edge"
    DROP CONSTRAINT IF EXISTS edge_client_id_fkey;
ALTER TABLE ONLY "edge"
    ADD CONSTRAINT edge_client_id_fkey
        FOREIGN KEY (client_id) REFERENCES "clients"(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "broker"
    DROP CONSTRAINT IF EXISTS broker_client_id_fkey;
ALTER TABLE ONLY "broker"
    ADD CONSTRAINT broker_client_id_fkey
        FOREIGN KEY (client_id) REFERENCES "clients"(id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS zone_client_id_index    ON "zone"    USING BTREE (client_id);
CREATE INDEX IF NOT EXISTS sys_client_id_index     ON "sys"     USING BTREE (client_id);
CREATE INDEX IF NOT EXISTS mod_client_id_index     ON "mod"     USING BTREE (client_id);
CREATE INDEX IF NOT EXISTS trigger_client_id_index ON "trigger" USING BTREE (client_id);
CREATE INDEX IF NOT EXISTS edge_client_id_index    ON "edge"    USING BTREE (client_id);
CREATE INDEX IF NOT EXISTS broker_client_id_index  ON "broker"  USING BTREE (client_id);

-- Per-client name uniqueness for the estate. Dormant while client_id is NULL
-- (UNIQUE treats NULLs as distinct) and strictly weaker than the current
-- model-level global uniqueness, so it cannot conflict with existing data.
-- When query enforcement lands, the model-level checks flip from global to
-- client-scoped and these indexes become the hard guarantee.
CREATE UNIQUE INDEX IF NOT EXISTS zone_client_id_name_unique
    ON "zone" USING BTREE (client_id, name) WHERE client_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS sys_client_id_name_unique
    ON "sys" USING BTREE (client_id, name) WHERE client_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS edge_client_id_name_unique
    ON "edge" USING BTREE (client_id, name) WHERE client_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS broker_client_id_name_unique
    ON "broker" USING BTREE (client_id, name) WHERE client_id IS NOT NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP INDEX IF EXISTS broker_client_id_name_unique;
DROP INDEX IF EXISTS edge_client_id_name_unique;
DROP INDEX IF EXISTS sys_client_id_name_unique;
DROP INDEX IF EXISTS zone_client_id_name_unique;

DROP INDEX IF EXISTS broker_client_id_index;
DROP INDEX IF EXISTS edge_client_id_index;
DROP INDEX IF EXISTS trigger_client_id_index;
DROP INDEX IF EXISTS mod_client_id_index;
DROP INDEX IF EXISTS sys_client_id_index;
DROP INDEX IF EXISTS zone_client_id_index;

ALTER TABLE ONLY "broker"  DROP CONSTRAINT IF EXISTS broker_client_id_fkey;
ALTER TABLE ONLY "edge"    DROP CONSTRAINT IF EXISTS edge_client_id_fkey;
ALTER TABLE ONLY "trigger" DROP CONSTRAINT IF EXISTS trigger_client_id_fkey;
ALTER TABLE ONLY "mod"     DROP CONSTRAINT IF EXISTS mod_client_id_fkey;
ALTER TABLE ONLY "sys"     DROP CONSTRAINT IF EXISTS sys_client_id_fkey;
ALTER TABLE ONLY "zone"    DROP CONSTRAINT IF EXISTS zone_client_id_fkey;

ALTER TABLE "broker"  DROP COLUMN IF EXISTS client_id;
ALTER TABLE "edge"    DROP COLUMN IF EXISTS client_id;
ALTER TABLE "trigger" DROP COLUMN IF EXISTS client_id;
ALTER TABLE "mod"     DROP COLUMN IF EXISTS client_id;
ALTER TABLE "sys"     DROP COLUMN IF EXISTS client_id;
ALTER TABLE "zone"    DROP COLUMN IF EXISTS client_id;

DROP INDEX IF EXISTS authority_domain_unique;
DROP INDEX IF EXISTS authority_client_id_index;
ALTER TABLE ONLY "authority" DROP CONSTRAINT IF EXISTS authority_client_id_fkey;
ALTER TABLE "authority" DROP COLUMN IF EXISTS client_id;

DROP TABLE IF EXISTS "clients";
DROP TABLE IF EXISTS "partners";
