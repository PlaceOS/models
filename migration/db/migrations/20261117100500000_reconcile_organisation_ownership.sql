-- +micrate Up
-- Retry only unassigned ownership using conservative inference. Existing owners
-- are never corrected automatically: the report below exposes them for review.
-- 3. Zones via org_zone → root-zone walk (unambiguous owners only).
--    UNION (not UNION ALL) so accidental cycles in zone parentage terminate.
--    Ambiguity is judged per TREE, not per org_zone string: every authority's
--    org_zone claim is resolved to its tree root, a tree claimed by more than
--    one distinct organisation is vetoed, and ownership is only assigned when at
--    least one claim names the root itself (a claim on a sub-zone alone must
--    not annex the whole tree). Rows whose (organisation_id, name) would collide
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
         a.organisation_id
  FROM "authority" a
  INNER JOIN zone_roots r ON r.id = a.config->>'org_zone'
  WHERE COALESCE(a.config->>'org_zone', '') <> ''
    AND a.organisation_id IS NOT NULL
  UNION ALL
  SELECT r.root_id, false AS names_root, z.organisation_id
  FROM "zone" z
  INNER JOIN zone_roots r ON r.id = z.id
  WHERE z.organisation_id IS NOT NULL
),
org_owner AS (
  SELECT root_id, MIN(organisation_id::text)::uuid AS organisation_id
  FROM tree_claims
  GROUP BY root_id
  HAVING COUNT(DISTINCT organisation_id) = 1
     AND bool_or(names_root)
),
candidates AS (
  SELECT z.id, o.organisation_id, z.name,
         ROW_NUMBER() OVER (
           PARTITION BY o.organisation_id, z.name
           ORDER BY z.created_at, z.id
         ) AS rn
  FROM "zone" z
  INNER JOIN zone_roots r ON z.id = r.id
  INNER JOIN org_owner o ON r.root_id = o.root_id
  WHERE z.organisation_id IS NULL
)
UPDATE "zone" z
SET organisation_id = c.organisation_id
FROM candidates c
WHERE z.id = c.id
  AND c.rn = 1
  AND NOT EXISTS (
    SELECT 1 FROM "zone" x
    WHERE x.organisation_id = c.organisation_id AND x.name = z.name AND x.id <> z.id
  );
-- +micrate StatementEnd

-- 4. Systems: single distinct organisation across their zones. Same collision
--    skip as zones (sys carries a (organisation_id, name) partial unique index).
-- +micrate StatementBegin
WITH sys_candidates AS (
  SELECT s2.id AS sys_id, s2.name,
         MIN(z.organisation_id::text)::uuid AS organisation_id
  FROM "sys" s2
  CROSS JOIN LATERAL unnest(s2.zones) AS reference(zone_id)
  LEFT JOIN "zone" z ON z.id = reference.zone_id
  WHERE s2.organisation_id IS NULL
  GROUP BY s2.id, s2.name
  HAVING COUNT(DISTINCT z.organisation_id) = 1
     AND bool_and(z.organisation_id IS NOT NULL)
),
ranked AS (
  SELECT sys_id, name, organisation_id,
         ROW_NUMBER() OVER (
           PARTITION BY organisation_id, name
           ORDER BY sys_id
         ) AS rn
  FROM sys_candidates
)
UPDATE "sys" s
SET organisation_id = r.organisation_id
FROM ranked r
WHERE s.id = r.sys_id
  AND r.rn = 1
  AND NOT EXISTS (
    SELECT 1 FROM "sys" x
    WHERE x.organisation_id = r.organisation_id AND x.name = s.name AND x.id <> s.id
  );
-- +micrate StatementEnd

-- 5. All module ownership sources must agree, including references from systems
--    other than a logic module's parent. Unknown/missing owners veto inference.
-- +micrate StatementBegin
WITH module_systems AS (
  SELECT id AS mod_id, control_system_id AS sys_id
  FROM "mod" WHERE control_system_id IS NOT NULL
  UNION
  SELECT m.id AS mod_id, s.id AS sys_id
  FROM "mod" m INNER JOIN "sys" s ON m.id = ANY(s.modules)
),
module_owners AS (
  SELECT links.mod_id, MIN(s.organisation_id::text)::uuid AS organisation_id
  FROM module_systems links
  LEFT JOIN "sys" s ON s.id = links.sys_id
  GROUP BY links.mod_id
  HAVING COUNT(DISTINCT s.organisation_id) = 1
     AND bool_and(s.organisation_id IS NOT NULL)
)
UPDATE "mod" m
SET organisation_id = owners.organisation_id
FROM module_owners owners
WHERE m.id = owners.mod_id AND m.organisation_id IS NULL
  AND (
    COALESCE(m.edge_id, '') = ''
    OR EXISTS (
      SELECT 1 FROM "edge" e
      WHERE e.id = m.edge_id AND e.organisation_id = owners.organisation_id
    )
  );
-- +micrate StatementEnd

-- 6. System-scoped trigger definitions
UPDATE "trigger" t
SET organisation_id = s.organisation_id
FROM "sys" s
WHERE t.control_system_id = s.id
  AND s.organisation_id IS NOT NULL
  AND t.organisation_id IS NULL;

-- 7. Edges via their bound user's authority. Same collision skip (edge
--    carries a (organisation_id, name) partial unique index).
-- +micrate StatementBegin
WITH edge_candidates AS (
  SELECT e.id, e.name, a.organisation_id,
         ROW_NUMBER() OVER (
           PARTITION BY a.organisation_id, e.name
           ORDER BY e.id
         ) AS rn
  FROM "edge" e
  INNER JOIN "user" u ON e.user_id = u.id
  INNER JOIN "authority" a ON u.authority_id = a.id
  WHERE a.organisation_id IS NOT NULL
    AND e.organisation_id IS NULL
)
UPDATE "edge" e
SET organisation_id = c.organisation_id
FROM edge_candidates c
WHERE e.id = c.id
  AND c.rn = 1
  AND NOT EXISTS (
    SELECT 1 FROM "edge" x
    WHERE x.organisation_id = c.organisation_id AND x.name = e.name AND x.id <> e.id
  );
-- +micrate StatementEnd


-- A durable, read-only inventory surface for explicit reconciliation. NULL
-- brokers and unscoped triggers are intentional platform resources, not orphans.
CREATE OR REPLACE VIEW tenancy_ownership_conflicts AS
WITH resources AS (
  SELECT 'authority'::text AS resource_type, id AS resource_id, organisation_id FROM authority
  UNION ALL SELECT 'zone', id, organisation_id FROM zone
  UNION ALL SELECT 'sys', id, organisation_id FROM sys
  UNION ALL SELECT 'mod', id, organisation_id FROM mod
  UNION ALL SELECT 'edge', id, organisation_id FROM edge
  UNION ALL SELECT 'broker', id, organisation_id FROM broker WHERE organisation_id IS NOT NULL
  UNION ALL SELECT 'trigger', id, organisation_id FROM "trigger"
    WHERE organisation_id IS NOT NULL OR control_system_id IS NOT NULL
), links AS (
  SELECT 'zone'::text AS resource_type, z.id AS resource_id, z.organisation_id,
         'zone'::text AS related_type, z.parent_id AS related_id,
         p.organisation_id AS related_organisation_id, p.id IS NOT NULL AS present
  FROM zone z LEFT JOIN zone p ON p.id = z.parent_id
  WHERE COALESCE(z.parent_id, '') <> ''
  UNION ALL
  SELECT 'authority', a.id, a.organisation_id, 'zone', a.config->>'org_zone', z.organisation_id, z.id IS NOT NULL
  FROM authority a LEFT JOIN zone z ON z.id = a.config->>'org_zone'
  WHERE COALESCE(a.config->>'org_zone', '') <> ''
  UNION ALL
  SELECT 'sys', s.id, s.organisation_id, 'zone', reference.id, z.organisation_id, z.id IS NOT NULL
  FROM sys s CROSS JOIN LATERAL unnest(s.zones) AS reference(id)
  LEFT JOIN zone z ON z.id = reference.id
  UNION ALL
  SELECT 'sys', s.id, s.organisation_id, 'mod', reference.id, m.organisation_id, m.id IS NOT NULL
  FROM sys s CROSS JOIN LATERAL unnest(s.modules) AS reference(id)
  LEFT JOIN mod m ON m.id = reference.id
  UNION ALL
  SELECT 'mod', m.id, m.organisation_id, 'sys', m.control_system_id, s.organisation_id, s.id IS NOT NULL
  FROM mod m LEFT JOIN sys s ON s.id = m.control_system_id
  WHERE m.control_system_id IS NOT NULL
  UNION ALL
  SELECT 'mod', m.id, m.organisation_id, 'sys', s.id, s.organisation_id, true
  FROM mod m INNER JOIN sys s ON m.id = ANY(s.modules)
  UNION ALL
  SELECT 'mod', m.id, m.organisation_id, 'edge', m.edge_id, e.organisation_id, e.id IS NOT NULL
  FROM mod m LEFT JOIN edge e ON e.id = m.edge_id
  WHERE m.edge_id IS NOT NULL
  UNION ALL
  SELECT 'trigger', t.id, t.organisation_id, 'sys', t.control_system_id, s.organisation_id, s.id IS NOT NULL
  FROM "trigger" t LEFT JOIN sys s ON s.id = t.control_system_id
  WHERE t.control_system_id IS NOT NULL
  UNION ALL
  SELECT 'edge', e.id, e.organisation_id, 'user', e.user_id, a.organisation_id,
         u.id IS NOT NULL AND a.id IS NOT NULL
  FROM edge e LEFT JOIN "user" u ON u.id = e.user_id
  LEFT JOIN authority a ON a.id = u.authority_id
)
SELECT resource_type, resource_id, organisation_id, 'unknown_owner'::text AS reason,
       NULL::text AS related_type, NULL::text AS related_id,
       NULL::uuid AS related_organisation_id
FROM resources WHERE organisation_id IS NULL
UNION
SELECT resource_type, resource_id, organisation_id,
       CASE WHEN NOT present THEN 'missing_reference'
            WHEN organisation_id IS NULL OR related_organisation_id IS NULL THEN 'unknown_reference'
            ELSE 'ownership_mismatch' END AS reason,
       related_type, related_id, related_organisation_id
FROM links
WHERE NOT present OR organisation_id IS NULL OR related_organisation_id IS NULL
   OR organisation_id <> related_organisation_id
UNION
SELECT l.resource_type, l.resource_id, l.organisation_id, 'shared_reference' AS reason,
       l.related_type, l.related_id, l.related_organisation_id
FROM links l
WHERE l.resource_type = 'mod' AND l.organisation_id IS NULL
  AND l.related_type = 'sys' AND l.resource_id IN (
    SELECT resource_id FROM links WHERE resource_type = 'mod' AND related_type = 'sys'
    GROUP BY resource_id HAVING COUNT(DISTINCT related_organisation_id) > 1
  );

-- +micrate Down
DROP VIEW IF EXISTS tenancy_ownership_conflicts;
-- Inferred ownership is retained: rollback must not erase reviewed assignments.
