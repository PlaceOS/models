-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- MERGE-TIME CHECK: micrate refuses out-of-order version ids (see models#323).
-- If any later-dated migration lands on master before this merges, renumber
-- this file AND 20261007100600000 above it (preserving schema-before-backfill
-- order). Safe: neither has been applied anywhere and the backfill is
-- idempotent.

-- ---------------------------------------------------------------------------
-- PPT-526: the Partner → Organisation → Authority(domain) hierarchy.
--
-- partners: integrators/resellers (e.g. NTT). `management = true` marks the
-- platform operator's own organisation (PlaceOS staff) — the "management
-- organisation" concept from the ticket, done at the partner level. `parent_id`
-- reserves a 2-tier channel (distributor → reseller) without any UI or
-- enforcement yet.
--
-- organisations: the customer organisation (e.g. UCLA, Acadian). `partner_id` NULL
-- means organisation-owned (self-managed, no integrator). `payer` records who is
-- invoiced: 'partner' (integrator pays us and re-bills, the default channel
-- model) or 'organisation' (direct). A organisation without a partner can only pay for
-- itself — enforced by CHECK.
--
-- Every delete path is RESTRICT: removing a partner/organisation must go through an
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

CREATE TABLE IF NOT EXISTS "organisations"(
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    partner_id UUID REFERENCES "partners"(id) ON DELETE RESTRICT,
    payer TEXT NOT NULL DEFAULT 'partner'
        CHECK (payer IN ('partner', 'organisation')),
    config JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT organisations_payer_requires_partner
        CHECK (partner_id IS NOT NULL OR payer = 'organisation')
);

-- Organisation names are unique within a partner's book of business, and unique
-- among organisation-owned organisations. Two partial indexes because UNIQUE treats
-- NULLs as distinct — a plain UNIQUE (partner_id, name) would let every
-- organisation-owned organisation share a name.
CREATE UNIQUE INDEX IF NOT EXISTS organisations_name_unique_per_partner
    ON "organisations" USING BTREE (partner_id, name) WHERE partner_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS organisations_name_unique_owned
    ON "organisations" USING BTREE (name) WHERE partner_id IS NULL;
CREATE INDEX IF NOT EXISTS organisations_partner_id_index
    ON "organisations" USING BTREE (partner_id);

-- ---------------------------------------------------------------------------
-- Authority → Organisation ownership. Nullable at the DB level for backwards
-- compatibility (init seeds authorities before any organisation exists); the
-- provisioning flow and backfill populate it. RESTRICT so a organisation cannot be
-- deleted while it still owns domains.
-- ---------------------------------------------------------------------------
ALTER TABLE "authority"
    ADD COLUMN IF NOT EXISTS organisation_id UUID;

ALTER TABLE ONLY "authority"
    DROP CONSTRAINT IF EXISTS authority_organisation_id_fkey;
ALTER TABLE ONLY "authority"
    ADD CONSTRAINT authority_organisation_id_fkey
        FOREIGN KEY (organisation_id) REFERENCES "organisations"(id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS authority_organisation_id_index
    ON "authority" USING BTREE (organisation_id);

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
-- Organisation ownership columns on the (previously cluster-global) control plane.
-- Nullable: populated by the backfill migration where inference is
-- unambiguous, and by the provisioning flow for everything new. Query-path
-- enforcement is phased in separately (rest-api); these columns are the
-- ground truth it will filter on.
-- ---------------------------------------------------------------------------
ALTER TABLE "zone"    ADD COLUMN IF NOT EXISTS organisation_id UUID;
ALTER TABLE "sys"     ADD COLUMN IF NOT EXISTS organisation_id UUID;
ALTER TABLE "mod"     ADD COLUMN IF NOT EXISTS organisation_id UUID;
ALTER TABLE "trigger" ADD COLUMN IF NOT EXISTS organisation_id UUID;
ALTER TABLE "edge"    ADD COLUMN IF NOT EXISTS organisation_id UUID;
ALTER TABLE "broker"  ADD COLUMN IF NOT EXISTS organisation_id UUID;

ALTER TABLE ONLY "zone"
    DROP CONSTRAINT IF EXISTS zone_organisation_id_fkey;
ALTER TABLE ONLY "zone"
    ADD CONSTRAINT zone_organisation_id_fkey
        FOREIGN KEY (organisation_id) REFERENCES "organisations"(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "sys"
    DROP CONSTRAINT IF EXISTS sys_organisation_id_fkey;
ALTER TABLE ONLY "sys"
    ADD CONSTRAINT sys_organisation_id_fkey
        FOREIGN KEY (organisation_id) REFERENCES "organisations"(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "mod"
    DROP CONSTRAINT IF EXISTS mod_organisation_id_fkey;
ALTER TABLE ONLY "mod"
    ADD CONSTRAINT mod_organisation_id_fkey
        FOREIGN KEY (organisation_id) REFERENCES "organisations"(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "trigger"
    DROP CONSTRAINT IF EXISTS trigger_organisation_id_fkey;
ALTER TABLE ONLY "trigger"
    ADD CONSTRAINT trigger_organisation_id_fkey
        FOREIGN KEY (organisation_id) REFERENCES "organisations"(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "edge"
    DROP CONSTRAINT IF EXISTS edge_organisation_id_fkey;
ALTER TABLE ONLY "edge"
    ADD CONSTRAINT edge_organisation_id_fkey
        FOREIGN KEY (organisation_id) REFERENCES "organisations"(id) ON DELETE RESTRICT;
ALTER TABLE ONLY "broker"
    DROP CONSTRAINT IF EXISTS broker_organisation_id_fkey;
ALTER TABLE ONLY "broker"
    ADD CONSTRAINT broker_organisation_id_fkey
        FOREIGN KEY (organisation_id) REFERENCES "organisations"(id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS zone_organisation_id_index    ON "zone"    USING BTREE (organisation_id);
CREATE INDEX IF NOT EXISTS sys_organisation_id_index     ON "sys"     USING BTREE (organisation_id);
CREATE INDEX IF NOT EXISTS mod_organisation_id_index     ON "mod"     USING BTREE (organisation_id);
CREATE INDEX IF NOT EXISTS trigger_organisation_id_index ON "trigger" USING BTREE (organisation_id);
CREATE INDEX IF NOT EXISTS edge_organisation_id_index    ON "edge"    USING BTREE (organisation_id);
CREATE INDEX IF NOT EXISTS broker_organisation_id_index  ON "broker"  USING BTREE (organisation_id);

-- Per-organisation name uniqueness for the estate. Dormant while organisation_id is NULL
-- (UNIQUE treats NULLs as distinct) and strictly weaker than the current
-- model-level global uniqueness, so it cannot conflict with existing data.
-- When query enforcement lands, the model-level checks flip from global to
-- organisation-scoped and these indexes become the hard guarantee.
CREATE UNIQUE INDEX IF NOT EXISTS zone_organisation_id_name_unique
    ON "zone" USING BTREE (organisation_id, name) WHERE organisation_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS sys_organisation_id_name_unique
    ON "sys" USING BTREE (organisation_id, name) WHERE organisation_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS edge_organisation_id_name_unique
    ON "edge" USING BTREE (organisation_id, name) WHERE organisation_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS broker_organisation_id_name_unique
    ON "broker" USING BTREE (organisation_id, name) WHERE organisation_id IS NOT NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP INDEX IF EXISTS broker_organisation_id_name_unique;
DROP INDEX IF EXISTS edge_organisation_id_name_unique;
DROP INDEX IF EXISTS sys_organisation_id_name_unique;
DROP INDEX IF EXISTS zone_organisation_id_name_unique;

DROP INDEX IF EXISTS broker_organisation_id_index;
DROP INDEX IF EXISTS edge_organisation_id_index;
DROP INDEX IF EXISTS trigger_organisation_id_index;
DROP INDEX IF EXISTS mod_organisation_id_index;
DROP INDEX IF EXISTS sys_organisation_id_index;
DROP INDEX IF EXISTS zone_organisation_id_index;

ALTER TABLE ONLY "broker"  DROP CONSTRAINT IF EXISTS broker_organisation_id_fkey;
ALTER TABLE ONLY "edge"    DROP CONSTRAINT IF EXISTS edge_organisation_id_fkey;
ALTER TABLE ONLY "trigger" DROP CONSTRAINT IF EXISTS trigger_organisation_id_fkey;
ALTER TABLE ONLY "mod"     DROP CONSTRAINT IF EXISTS mod_organisation_id_fkey;
ALTER TABLE ONLY "sys"     DROP CONSTRAINT IF EXISTS sys_organisation_id_fkey;
ALTER TABLE ONLY "zone"    DROP CONSTRAINT IF EXISTS zone_organisation_id_fkey;

ALTER TABLE "broker"  DROP COLUMN IF EXISTS organisation_id;
ALTER TABLE "edge"    DROP COLUMN IF EXISTS organisation_id;
ALTER TABLE "trigger" DROP COLUMN IF EXISTS organisation_id;
ALTER TABLE "mod"     DROP COLUMN IF EXISTS organisation_id;
ALTER TABLE "sys"     DROP COLUMN IF EXISTS organisation_id;
ALTER TABLE "zone"    DROP COLUMN IF EXISTS organisation_id;

DROP INDEX IF EXISTS authority_domain_unique;
DROP INDEX IF EXISTS authority_organisation_id_index;
ALTER TABLE ONLY "authority" DROP CONSTRAINT IF EXISTS authority_organisation_id_fkey;
ALTER TABLE "authority" DROP COLUMN IF EXISTS organisation_id;

DROP TABLE IF EXISTS "organisations";
DROP TABLE IF EXISTS "partners";
