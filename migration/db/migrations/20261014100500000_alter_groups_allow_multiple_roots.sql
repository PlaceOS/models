-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- An authority may have several root groups, e.g. separate trees for the
-- departments that manage support and signage
DROP INDEX IF EXISTS groups_authority_single_root;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
-- (fails if an authority has more than one root group by then)

CREATE UNIQUE INDEX IF NOT EXISTS groups_authority_single_root
    ON "groups" (authority_id) WHERE parent_id IS NULL;
