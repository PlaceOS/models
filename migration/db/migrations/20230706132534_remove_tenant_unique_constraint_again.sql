-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- +micrate StatementBegin
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM   information_schema.table_constraints 
        WHERE  table_name   = 'tenants' 
        AND    constraint_name = 'unique_domain'
    )
    THEN
        ALTER TABLE tenants
        DROP CONSTRAINT unique_domain;
    END IF;
END $$;
-- +micrate StatementEnd

DROP INDEX concurrently IF EXISTS unique_domain;
DROP INDEX IF EXISTS unique_domain;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
