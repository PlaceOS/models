-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- Associate asset categories with an authority. Nullable at the DB level for
-- backwards compatibility with existing rows; presence is enforced at the model
-- level. ON DELETE CASCADE matches the playlist/signage authority convention.
ALTER TABLE "asset_category"
  ADD COLUMN IF NOT EXISTS authority_id TEXT;

ALTER TABLE ONLY "asset_category"
  DROP CONSTRAINT IF EXISTS asset_category_authority_id_fkey;

ALTER TABLE ONLY "asset_category"
  ADD CONSTRAINT asset_category_authority_id_fkey
    FOREIGN KEY (authority_id) REFERENCES "authority"(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS asset_category_authority_id_index
  ON "asset_category" USING BTREE (authority_id);

-- Supports the model-level uniqueness check on AssetCategory#name scoped to
-- authority_id (self.where(authority_id: ..., name: ...)). NOT a UNIQUE index —
-- uniqueness is enforced at the model level for backwards compatibility.
CREATE INDEX IF NOT EXISTS asset_category_authority_id_name_index
  ON "asset_category" USING BTREE (authority_id, name);

-- Supports the model-level uniqueness check on AssetType#name scoped to
-- category_id (self.where(category_id: ..., name: ...)). NOT a UNIQUE index.
CREATE INDEX IF NOT EXISTS asset_type_category_id_name_index
  ON "asset_type" USING BTREE (category_id, name);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP INDEX IF EXISTS asset_type_category_id_name_index;
DROP INDEX IF EXISTS asset_category_authority_id_name_index;
DROP INDEX IF EXISTS asset_category_authority_id_index;

ALTER TABLE ONLY "asset_category"
  DROP CONSTRAINT IF EXISTS asset_category_authority_id_fkey;

ALTER TABLE "asset_category"
  DROP COLUMN IF EXISTS authority_id;
