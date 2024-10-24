-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- +micrate StatementBegin

-- Cleanup function for oauth_access_grants
CREATE OR REPLACE FUNCTION cleanup_expired_grants() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM "oauth_access_grants"
    WHERE
        revoked_at IS NULL
        AND (created_at + (expires_in * interval '1 second')) < (now() - interval '3 months');
    RETURN NEW;
END $$;
-- +micrate StatementEnd

-- +micrate StatementBegin
-- Cleanup function for oauth_access_tokens
CREATE OR REPLACE FUNCTION cleanup_expired_tokens() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM "oauth_access_tokens"
    WHERE
        revoked_at IS NULL
        AND (created_at + (expires_in * interval '1 second')) < (now() - interval '3 months');
    RETURN NEW;
END $$;
-- +micrate StatementEnd

-- Trigger for oauth_access_grants
CREATE TRIGGER cleanup_on_insert_or_update_grants AFTER INSERT OR UPDATE ON "oauth_access_grants"
FOR EACH ROW EXECUTE FUNCTION cleanup_expired_grants();

-- Trigger for oauth_access_tokens
CREATE TRIGGER cleanup_on_insert_or_update_tokens AFTER INSERT OR UPDATE ON "oauth_access_tokens"
FOR EACH ROW EXECUTE FUNCTION cleanup_expired_tokens();


-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP TRIGGER IF EXISTS cleanup_on_insert_or_update_grants;
DROP TRIGGER IF EXISTS cleanup_on_insert_or_update_tokens;
DROP FUNCTION IF EXISTS cleanup_expired_grants();
DROP FUNCTION IF EXISTS cleanup_expired_tokens();

