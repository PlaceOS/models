-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE tenants ADD COLUMN IF NOT EXISTS email_domain TEXT;

DO $$
DECLARE 
    constraint_name VARCHAR;
BEGIN
    SELECT conname INTO constraint_name
    FROM pg_constraint 
    INNER JOIN pg_class ON conrelid=pg_class.oid 
    INNER JOIN pg_attribute ON pg_attribute.attnum=conkey[1] 
    WHERE relname='tenants' AND attname='domain';

    IF constraint_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE tenants DROP CONSTRAINT %I', constraint_name);
    END IF;
END $$;
 
-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE tenants DROP COLUMN email_domain;
ALTER TABLE tenants
ADD CONSTRAINT tenants_domain_key UNIQUE(domain);
