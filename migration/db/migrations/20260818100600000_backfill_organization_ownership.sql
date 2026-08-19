-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- ---------------------------------------------------------------------------
-- PPT-526: backfill Partner/Organization ownership for existing data.
--
-- Idempotent and additive: every statement only creates missing rows or fills
-- NULL organization_id columns, so it is safe to re-apply and safe on databases
-- where operators have already assigned ownership by hand. Where inference is
-- ambiguous the row is deliberately LEFT NULL for a human to resolve (the
-- org_zone convention is known to be non-exclusive and sometimes absent).
--
-- What it does:
--   1. Ensures a management partner exists ("PlaceOS" — the platform
--      operator's own organisation).
--   2. Creates one organization-owned Organization per Authority that has none, named
--      "<authority name> (<domain>)" (domain uniqueness makes this collision
--      free), and points the authority at it. Estates that span several
--      authorities under one real-world organization (e.g. NTT's two domains) are
--      merged later by re-pointing authority.organization_id by hand or API.
--   3. Zones: a zone belongs to the organization of the authority whose
--      config->>'org_zone' names the zone's ROOT zone — only when exactly one
--      organization is implied (shared org zones stay NULL).
--   4. Systems: the single distinct organization of their zones, if unambiguous.
--   5. Modules: logic modules via their control system; shared device/service
--      modules via the systems that reference them, if unambiguous.
--   6. Trigger definitions: via their control system when system-scoped;
--      unscoped trigger definitions stay NULL (shared library semantics).
--   7. Edges: via their bound user's authority.
--   Brokers are deliberately NOT backfilled (cluster-level MQTT infra).
-- ---------------------------------------------------------------------------

-- 1. Management partner. ON CONFLICT: if an operator already created a
--    non-management partner named 'PlaceOS', leave it for a human rather
--    than promote it (this file only creates missing rows / fills NULLs).
INSERT INTO "partners" (name, description, management, created_at, updated_at)
SELECT 'PlaceOS', 'Platform operator (management partner)', true, now(), now()
WHERE NOT EXISTS (SELECT 1 FROM "partners" WHERE management = true)
ON CONFLICT DO NOTHING;

-- 2. One organization-owned Organization per orphan Authority
-- +micrate StatementBegin
DO $$
DECLARE
  auth RECORD;
  new_org UUID;
BEGIN
  FOR auth IN SELECT id, name, domain FROM "authority" WHERE organization_id IS NULL LOOP
    new_org := NULL;
    INSERT INTO "organizations" (name, description, partner_id, payer, created_at, updated_at)
    VALUES (
      COALESCE(NULLIF(auth.name, ''), auth.domain) || ' (' || auth.domain || ')',
      'Auto-created from authority ' || auth.id || ' during PPT-526 organization backfill',
      NULL, 'organization', now(), now()
    )
    ON CONFLICT DO NOTHING
    RETURNING id INTO new_org;

    -- If the name already existed (re-run against a partially-backfilled DB),
    -- reuse the existing row rather than leaving the authority orphaned.
    IF new_org IS NULL THEN
      SELECT id INTO new_org FROM "organizations"
      WHERE partner_id IS NULL
        AND name = COALESCE(NULLIF(auth.name, ''), auth.domain) || ' (' || auth.domain || ')';
    END IF;

    IF new_org IS NOT NULL THEN
      UPDATE "authority" SET organization_id = new_org WHERE id = auth.id;
    END IF;
  END LOOP;
END $$;
-- +micrate StatementEnd

-- 3. Zones via org_zone → root-zone walk (unambiguous owners only).
--    UNION (not UNION ALL) so accidental cycles in zone parentage terminate.
--    Ambiguity is judged per TREE, not per org_zone string: every authority's
--    org_zone claim is resolved to its tree root, a tree claimed by more than
--    one distinct organization is vetoed, and ownership is only assigned when at
--    least one claim names the root itself (a claim on a sub-zone alone must
--    not annex the whole tree). Rows whose (organization_id, name) would collide
--    with the partial unique indexes are skipped (left NULL for a human) —
--    duplicate names within one estate are legacy race artifacts.
-- +micrate StatementBegin
WITH RECURSIVE zone_roots AS (
  SELECT id, id AS root_id
  FROM "zone"
  WHERE parent_id IS NULL OR parent_id = ''
  UNION
  SELECT z.id, r.root_id
  FROM "zone" z
  INNER JOIN zone_roots r ON z.parent_id = r.id
),
tree_claims AS (
  SELECT r.root_id,
         (a.config->>'org_zone' = r.root_id) AS names_root,
         a.organization_id
  FROM "authority" a
  INNER JOIN zone_roots r ON r.id = a.config->>'org_zone'
  WHERE COALESCE(a.config->>'org_zone', '') <> ''
    AND a.organization_id IS NOT NULL
),
org_owner AS (
  SELECT root_id, MIN(organization_id::text)::uuid AS organization_id
  FROM tree_claims
  GROUP BY root_id
  HAVING COUNT(DISTINCT organization_id) = 1
     AND bool_or(names_root)
),
candidates AS (
  SELECT z.id, o.organization_id, z.name,
         ROW_NUMBER() OVER (
           PARTITION BY o.organization_id, z.name
           ORDER BY z.created_at, z.id
         ) AS rn
  FROM "zone" z
  INNER JOIN zone_roots r ON z.id = r.id
  INNER JOIN org_owner o ON r.root_id = o.root_id
  WHERE z.organization_id IS NULL
)
UPDATE "zone" z
SET organization_id = c.organization_id
FROM candidates c
WHERE z.id = c.id
  AND c.rn = 1
  AND NOT EXISTS (
    SELECT 1 FROM "zone" x
    WHERE x.organization_id = c.organization_id AND x.name = z.name AND x.id <> z.id
  );
-- +micrate StatementEnd

-- 4. Systems: single distinct organization across their zones. Same collision
--    skip as zones (sys carries a (organization_id, name) partial unique index).
-- +micrate StatementBegin
WITH sys_candidates AS (
  SELECT s2.id AS sys_id, s2.name,
         MIN(z.organization_id::text)::uuid AS organization_id
  FROM "sys" s2
  INNER JOIN "zone" z ON z.id = ANY(s2.zones)
  WHERE z.organization_id IS NOT NULL
    AND s2.organization_id IS NULL
  GROUP BY s2.id, s2.name
  HAVING COUNT(DISTINCT z.organization_id) = 1
),
ranked AS (
  SELECT sys_id, name, organization_id,
         ROW_NUMBER() OVER (
           PARTITION BY organization_id, name
           ORDER BY sys_id
         ) AS rn
  FROM sys_candidates
)
UPDATE "sys" s
SET organization_id = r.organization_id
FROM ranked r
WHERE s.id = r.sys_id
  AND r.rn = 1
  AND NOT EXISTS (
    SELECT 1 FROM "sys" x
    WHERE x.organization_id = r.organization_id AND x.name = s.name AND x.id <> s.id
  );
-- +micrate StatementEnd

-- 5a. Logic modules via their control system
UPDATE "mod" m
SET organization_id = s.organization_id
FROM "sys" s
WHERE m.control_system_id = s.id
  AND s.organization_id IS NOT NULL
  AND m.organization_id IS NULL;

-- 5b. Device/service modules via the systems that reference them
UPDATE "mod" m
SET organization_id = sc.organization_id
FROM (
  SELECT m2.id AS mod_id, MIN(s.organization_id::text)::uuid AS organization_id
  FROM "mod" m2
  INNER JOIN "sys" s ON m2.id = ANY(s.modules)
  WHERE s.organization_id IS NOT NULL
  GROUP BY m2.id
  HAVING COUNT(DISTINCT s.organization_id) = 1
) sc
WHERE m.id = sc.mod_id AND m.organization_id IS NULL;

-- 6. System-scoped trigger definitions
UPDATE "trigger" t
SET organization_id = s.organization_id
FROM "sys" s
WHERE t.control_system_id = s.id
  AND s.organization_id IS NOT NULL
  AND t.organization_id IS NULL;

-- 7. Edges via their bound user's authority. Same collision skip (edge
--    carries a (organization_id, name) partial unique index).
-- +micrate StatementBegin
WITH edge_candidates AS (
  SELECT e.id, e.name, a.organization_id,
         ROW_NUMBER() OVER (
           PARTITION BY a.organization_id, e.name
           ORDER BY e.id
         ) AS rn
  FROM "edge" e
  INNER JOIN "user" u ON e.user_id = u.id
  INNER JOIN "authority" a ON u.authority_id = a.id
  WHERE a.organization_id IS NOT NULL
    AND e.organization_id IS NULL
)
UPDATE "edge" e
SET organization_id = c.organization_id
FROM edge_candidates c
WHERE e.id = c.id
  AND c.rn = 1
  AND NOT EXISTS (
    SELECT 1 FROM "edge" x
    WHERE x.organization_id = c.organization_id AND x.name = e.name AND x.id <> e.id
  );
-- +micrate StatementEnd

-- +micrate Down
-- Deliberate no-op: the backfill only fills NULLs and creates rows that
-- operators may since have adopted; unwinding it automatically could destroy
-- hand-made ownership assignments. Rolling back the schema migration
-- (20260818100500000) removes the columns and tables wholesale.
