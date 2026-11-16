-- +micrate Up
-- Correct only unassigned module ownership. Actual edge gateways are tenant-owned;
-- missing, unknown or conflicting edge ownership vetoes inference. Assigned owners
-- remain unchanged and appear in the reconciliation report for explicit review.
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
  )
UNION
SELECT 'authority', a.id, a.organisation_id, 'duplicate_domain', NULL::text, NULL::text, NULL::uuid
FROM authority a
WHERE EXISTS (SELECT 1 FROM authority duplicate WHERE duplicate.domain = a.domain AND duplicate.id <> a.id)
UNION
SELECT 'authority', a.id, a.organisation_id, 'quarantined_domain', NULL::text, NULL::text, NULL::uuid
FROM authority a
WHERE RIGHT(LOWER(a.domain), LENGTH('.duplicate.' || a.id)) = '.duplicate.' || LOWER(a.id);


-- +micrate Down
-- Keep reviewed ownership assignments and the non-destructive diagnostic view.
