-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE tenants ADD COLUMN parent_id BIGINT DEFAULT NULL;

ALTER TABLE tenants ADD CONSTRAINT fk_tenants_parent_id
    FOREIGN KEY (parent_id) 
    REFERENCES tenants(id)
    ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS index_tenants_parent_id_idx ON "tenants" USING HASH (parent_id);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE tenants DROP CONSTRAINT fk_tenants_parent_id;
DROP INDEX IF EXISTS index_tenants_parent_id_idx;
ALTER TABLE tenants DROP COLUMN parent_id;
