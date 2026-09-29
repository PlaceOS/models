-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- Permissions bitmask applied to new GroupUser rows that are created without
-- an explicit permissions value.
ALTER TABLE "groups" ADD COLUMN IF NOT EXISTS default_permissions INTEGER NOT NULL DEFAULT 0;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "groups" DROP COLUMN IF EXISTS default_permissions;
