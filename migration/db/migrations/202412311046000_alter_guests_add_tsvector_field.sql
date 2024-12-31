-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- +micrate StatementBegin
CREATE OR REPLACE FUNCTION tsv_search_tsvector_update() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.tsv_search := to_tsvector('simple',
        regexp_replace(
            COALESCE(NEW.email, '') || ' ' ||
            COALESCE(NEW.name, '') || ' ' ||
            COALESCE(NEW.preferred_name, '') || ' ' ||
            COALESCE(NEW.organisation, '') || ' ' ||
            COALESCE(NEW.phone, '') || ' ' ||
            COALESCE(NEW.id::TEXT, ''),
            '[@._]', ' ', 'g'
        ) || ' ' ||
        COALESCE(NEW.email, '')
    );
    RETURN NEW;
END $$;
-- +micrate StatementEnd

ALTER TABLE guests ADD COLUMN tsv_search tsvector DEFAULT ''::tsvector;

CREATE INDEX idx_tsv_search ON guests USING gin(tsv_search);

UPDATE guests
SET tsv_search = to_tsvector('simple',
    regexp_replace(
        COALESCE(email, '') || ' ' ||
        COALESCE(name, '') || ' ' ||
        COALESCE(preferred_name, '') || ' ' ||
        COALESCE(organisation, '') || ' ' ||
        COALESCE(phone, '') || ' ' ||
        COALESCE(id::TEXT, ''),
        '[@._]', ' ', 'g'
    ) || ' ' ||
    COALESCE(email, '')
);

CREATE TRIGGER tsv_search_trigger BEFORE INSERT OR UPDATE ON guests
FOR EACH ROW EXECUTE FUNCTION tsv_search_tsvector_update();

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP TRIGGER IF EXISTS tsv_search_trigger ON guests;
DROP FUNCTION IF EXISTS tsv_search_tsvector_update();
DROP INDEX IF EXISTS idx_tsv_search;
ALTER TABLE guests DROP COLUMN IF EXISTS tsv_search;