-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "asset"
    ADD COLUMN name TEXT,
    ADD COLUMN client_ids JSONB,
    ADD COLUMN map_id TEXT,
    ADD COLUMN bookable BOOLEAN DEFAULT TRUE,
    ADD COLUMN accessible BOOLEAN DEFAULT FALSE,
    ADD COLUMN zones TEXT[] DEFAULT '{}',
    ADD COLUMN place_groups TEXT[] DEFAULT '{}',
    ADD COLUMN assigned_to TEXT,
    ADD COLUMN assigned_name TEXT,
    ADD COLUMN features TEXT[] DEFAULT '{}',
    ADD COLUMN images TEXT[] DEFAULT '{}',
    ADD COLUMN notes TEXT,
    ADD COLUMN security_system_groups TEXT[] DEFAULT '{}',
    ADD COLUMN parent_id TEXT,
    ADD CONSTRAINT fk_asset_parent
        FOREIGN KEY (parent_id) REFERENCES asset(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_asset_map_id ON asset (map_id);
CREATE INDEX IF NOT EXISTS idx_asset_assigned_to ON asset (assigned_to);
CREATE INDEX IF NOT EXISTS idx_asset_assigned_name ON asset (assigned_name);
CREATE INDEX IF NOT EXISTS idx_asset_bookable ON asset (bookable);
CREATE INDEX IF NOT EXISTS idx_asset_accessible ON asset (accessible);
CREATE INDEX IF NOT EXISTS idx_asset_parent_id ON asset (parent_id);
CREATE INDEX IF NOT EXISTS idx_asset_client_ids ON asset USING gin (client_ids);
CREATE INDEX IF NOT EXISTS idx_asset_zones ON asset USING gin (zones);
CREATE INDEX IF NOT EXISTS idx_asset_place_groups ON asset USING gin (place_groups);
CREATE INDEX IF NOT EXISTS idx_asset_features ON asset USING gin (features);
CREATE INDEX IF NOT EXISTS idx_asset_images ON asset USING gin (images);
CREATE INDEX IF NOT EXISTS idx_asset_security_system_groups ON asset USING gin (security_system_groups);

ALTER TABLE "asset_category" ADD COLUMN IF NOT EXISTS hidden BOOLEAN DEFAULT FALSE;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP INDEX IF EXISTS idx_asset_security_system_groups;
DROP INDEX IF EXISTS idx_asset_images;
DROP INDEX IF EXISTS idx_asset_features;
DROP INDEX IF EXISTS idx_asset_place_groups;
DROP INDEX IF EXISTS idx_asset_zones;
DROP INDEX IF EXISTS idx_asset_client_ids;
DROP INDEX IF EXISTS idx_asset_parent_id;
DROP INDEX IF EXISTS idx_asset_accessible;
DROP INDEX IF EXISTS idx_asset_bookable;
DROP INDEX IF EXISTS idx_asset_assigned_name;
DROP INDEX IF EXISTS idx_asset_assigned_to;
DROP INDEX IF EXISTS idx_asset_map_id;

ALTER TABLE asset
    DROP CONSTRAINT fk_asset_parent,
    DROP COLUMN parent_id,
    DROP COLUMN security_system_groups,
    DROP COLUMN notes,
    DROP COLUMN images,
    DROP COLUMN features,
    DROP COLUMN assigned_name,
    DROP COLUMN assigned_to,
    DROP COLUMN place_groups,
    DROP COLUMN zones,
    DROP COLUMN accessible,
    DROP COLUMN bookable,
    DROP COLUMN map_id,
    DROP COLUMN client_ids,
    DROP COLUMN name;

ALTER TABLE "asset_category" DROP COLUMN hidden