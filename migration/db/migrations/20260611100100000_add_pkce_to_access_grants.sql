-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- Doorkeeper enables PKCE support when these columns exist.
-- Required for native apps (public clients) using the Authorization Code flow
-- as they cannot protect a client secret.
--
-- Ruby (Rails) equivalent:
--   add_column :oauth_access_grants, :code_challenge, :string, null: true
--   add_column :oauth_access_grants, :code_challenge_method, :string, null: true

ALTER TABLE "oauth_access_grants"
  ADD COLUMN IF NOT EXISTS code_challenge character varying,
  ADD COLUMN IF NOT EXISTS code_challenge_method character varying;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "oauth_access_grants"
  DROP COLUMN IF EXISTS code_challenge,
  DROP COLUMN IF EXISTS code_challenge_method;
