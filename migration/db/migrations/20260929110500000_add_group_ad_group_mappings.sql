-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- AD group id => [display name, permissions bitmask]. Users in a mapped AD
-- group are automatically added to the group.
ALTER TABLE "groups" ADD COLUMN IF NOT EXISTS ad_group_mappings JSONB NOT NULL DEFAULT '{}';

-- Supports the `ad_group_mappings ?| array[...]` lookup when syncing a user.
CREATE INDEX IF NOT EXISTS groups_ad_group_mappings_index
    ON "groups" USING GIN (ad_group_mappings);

-- The AD group id that caused this membership to be added automatically.
-- NULL for memberships that were added manually.
ALTER TABLE "group_users" ADD COLUMN IF NOT EXISTS auto_assigned TEXT;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "group_users" DROP COLUMN IF EXISTS auto_assigned;
DROP INDEX IF EXISTS groups_ad_group_mappings_index;
ALTER TABLE "groups" DROP COLUMN IF EXISTS ad_group_mappings;
