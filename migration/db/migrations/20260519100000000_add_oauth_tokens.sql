-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- ---------------------------------------------------------------------------
-- OAuthToken: per-token metadata for issued OAuth2 access + refresh tokens.
--
-- Used by the auth.cr service (replacing the legacy Ruby Doorkeeper
-- service) for two purposes:
--   1. Token revocation — `revoked_at` flips from NULL to a unix
--      timestamp on revoke. The authly shard's TokenStore checks
--      revoked_at on every Bearer-token validation.
--   2. Audit / introspection — `/auth/introspect` returns the issuing
--      client, sub, scope, and lifetime.
--
-- Token IDs (`jti`) are 64 hex chars (Random::Secure.hex(32)). Most
-- fields are nullable so we can record a "revoke first, fill in
-- details if we later see the row" pattern — important because authly
-- generates refresh tokens without calling `store_token_metadata`
-- (refresh tokens are stateless JWTs even when `persist_jwt_tokens`
-- is on); revoking such a refresh token still needs to leave a marker.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "oauth_tokens"(
    id bigserial PRIMARY KEY,
    jti character varying NOT NULL,
    token_type character varying,
    client_id character varying,
    sub character varying,
    scope character varying,
    issued_at bigint,
    expires_at bigint,
    cert_thumbprint character varying,
    revoked_at bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS index_oauth_tokens_on_jti ON "oauth_tokens" USING btree (jti);
CREATE INDEX IF NOT EXISTS index_oauth_tokens_on_expires_at ON "oauth_tokens" USING btree (expires_at);

-- +micrate Down
DROP TABLE IF EXISTS "oauth_tokens";
