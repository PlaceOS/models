-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- PPT-2644: PostgreSQL full-text search columns replacing Elasticsearch.
-- Every searchable table gets a generated, stored tsvector maintained by
-- PostgreSQL itself and a GIN index for fast matching. The 'simple'
-- configuration is used on both write and query side (see guests.tsv_search
-- precedent): entity names, identifiers and emails must not be stemmed.
-- Secrets and encrypted content (password digests, tokens, client secrets,
-- IdP certificates, settings_string) are deliberately excluded from vectors.
--
-- This migration is idempotent: every statement is guarded (CREATE OR REPLACE /
-- IF NOT EXISTS) so it can safely be re-applied. Note that an existing
-- search_vector column is left as-is rather than redefined; to change a vector
-- expression, drop the column in a new migration first.

-- array_to_string is only STABLE, so generated columns can't call it
-- directly; for text[] input it is in fact immutable, hence this wrapper.
-- +micrate StatementBegin
CREATE OR REPLACE FUNCTION placeos_fts_join(arr text[]) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT COALESCE(array_to_string(arr, ' '), '')
$$;
-- +micrate StatementEnd

-- Emails are additionally split on [@._] so partial-token search works
-- (e.g. "reeves" or "place" matches "cam.reeves@place.tech"), while the
-- raw address is kept for whole-address matching.
-- +micrate StatementBegin
CREATE OR REPLACE FUNCTION placeos_fts_email(addr text) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT regexp_replace(COALESCE(addr, ''), '[@._]', ' ', 'g') || ' ' || COALESCE(addr, '')
$$;
-- +micrate StatementEnd

-- URIs and file paths are split on all punctuation so their segments are
-- individually prefix-searchable ("swit" matches ".../video_switcher.cr"),
-- while the raw value is kept for whole-string matching. Elasticsearch's
-- analyzer segmented these fields the same way.
-- +micrate StatementBegin
CREATE OR REPLACE FUNCTION placeos_fts_uri(addr text) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT regexp_replace(COALESCE(addr, ''), '[^[:alnum:]]+', ' ', 'g') || ' ' || COALESCE(addr, '')
$$;
-- +micrate StatementEnd

ALTER TABLE "sys" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(name, '') || ' ' || COALESCE(display_name, '') || ' ' || COALESCE(code, '') || ' ' ||
    COALESCE(type, '') || ' ' || COALESCE(description, '') || ' ' ||
    placeos_fts_join(features) || ' ' || placeos_fts_email(email) || ' ' || COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_sys_search_vector ON "sys" USING GIN (search_vector);

ALTER TABLE "mod" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(custom_name, '') || ' ' || COALESCE(name, '') || ' ' || COALESCE(ip, '') || ' ' ||
    placeos_fts_uri(uri) || ' ' || COALESCE(notes, '') || ' ' || COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_mod_search_vector ON "mod" USING GIN (search_vector);

ALTER TABLE "driver" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(name, '') || ' ' || COALESCE(module_name, '') || ' ' || placeos_fts_uri(file_name) || ' ' ||
    COALESCE(description, '') || ' ' || placeos_fts_uri(default_uri) || ' ' || COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_driver_search_vector ON "driver" USING GIN (search_vector);

ALTER TABLE "zone" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(name, '') || ' ' || COALESCE(display_name, '') || ' ' || COALESCE(code, '') || ' ' ||
    COALESCE(type, '') || ' ' || COALESCE(description, '') || ' ' || COALESCE(location, '') || ' ' ||
    placeos_fts_join(tags) || ' ' || COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_zone_search_vector ON "zone" USING GIN (search_vector);

ALTER TABLE "user" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(name, '') || ' ' || COALESCE(nickname, '') || ' ' || placeos_fts_email(email) || ' ' ||
    COALESCE(login_name, '') || ' ' || COALESCE(staff_id, '') || ' ' ||
    COALESCE(first_name, '') || ' ' || COALESCE(last_name, '') || ' ' ||
    COALESCE(department, '') || ' ' || COALESCE(building, '') || ' ' ||
    COALESCE(phone, '') || ' ' || COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_user_search_vector ON "user" USING GIN (search_vector);

ALTER TABLE "repo" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(name, '') || ' ' || COALESCE(folder_name, '') || ' ' || placeos_fts_uri(uri) || ' ' ||
    COALESCE(description, '') || ' ' || COALESCE(branch, '') || ' ' || COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_repo_search_vector ON "repo" USING GIN (search_vector);

ALTER TABLE "trigger" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(name, '') || ' ' || COALESCE(description, '') || ' ' || COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_trigger_search_vector ON "trigger" USING GIN (search_vector);

ALTER TABLE "authority" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(name, '') || ' ' || COALESCE(domain, '') || ' ' || COALESCE(description, '') || ' ' ||
    COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_authority_search_vector ON "authority" USING GIN (search_vector);

ALTER TABLE "ldap_strat" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple', COALESCE(name, '') || ' ' || COALESCE(id::text, ''))
) STORED;
CREATE INDEX IF NOT EXISTS idx_ldap_strat_search_vector ON "ldap_strat" USING GIN (search_vector);

ALTER TABLE "oauth_strat" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple', COALESCE(name, '') || ' ' || COALESCE(id::text, ''))
) STORED;
CREATE INDEX IF NOT EXISTS idx_oauth_strat_search_vector ON "oauth_strat" USING GIN (search_vector);

ALTER TABLE "adfs_strat" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple', COALESCE(name, '') || ' ' || COALESCE(id::text, ''))
) STORED;
CREATE INDEX IF NOT EXISTS idx_adfs_strat_search_vector ON "adfs_strat" USING GIN (search_vector);

ALTER TABLE "edge" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(name, '') || ' ' || COALESCE(description, '') || ' ' || COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_edge_search_vector ON "edge" USING GIN (search_vector);

ALTER TABLE "api_key" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(name, '') || ' ' || COALESCE(description, '') || ' ' || COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_api_key_search_vector ON "api_key" USING GIN (search_vector);

ALTER TABLE "oauth_applications" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(name, '') || ' ' || COALESCE(uid, '') || ' ' || COALESCE(redirect_uri, '') || ' ' ||
    COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_oauth_applications_search_vector ON "oauth_applications" USING GIN (search_vector);

ALTER TABLE "sets" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple', placeos_fts_join(keys) || ' ' || COALESCE(id::text, ''))
) STORED;
CREATE INDEX IF NOT EXISTS idx_sets_search_vector ON "sets" USING GIN (search_vector);

ALTER TABLE "json_schema" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(name, '') || ' ' || COALESCE(description, '') || ' ' || COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_json_schema_search_vector ON "json_schema" USING GIN (search_vector);

ALTER TABLE "asset" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(name, '') || ' ' || COALESCE(identifier, '') || ' ' || COALESCE(serial_number, '') || ' ' ||
    COALESCE(barcode, '') || ' ' || COALESCE(assigned_name, '') || ' ' || COALESCE(assigned_to, '') || ' ' ||
    COALESCE(notes, '') || ' ' || COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_asset_search_vector ON "asset" USING GIN (search_vector);

ALTER TABLE "asset_type" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(name, '') || ' ' || COALESCE(brand, '') || ' ' || COALESCE(model_number, '') || ' ' ||
    COALESCE(description, '') || ' ' || COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_asset_type_search_vector ON "asset_type" USING GIN (search_vector);

ALTER TABLE "asset_category" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(name, '') || ' ' || COALESCE(description, '') || ' ' || COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_asset_category_search_vector ON "asset_category" USING GIN (search_vector);

ALTER TABLE "asset_purchase_order" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(purchase_order_number, '') || ' ' || COALESCE(invoice_number, '') || ' ' ||
    COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_asset_purchase_order_search_vector ON "asset_purchase_order" USING GIN (search_vector);

ALTER TABLE "alert" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(name, '') || ' ' || COALESCE(description, '') || ' ' || COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_alert_search_vector ON "alert" USING GIN (search_vector);

ALTER TABLE "alert_dashboard" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(name, '') || ' ' || COALESCE(description, '') || ' ' || COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_alert_dashboard_search_vector ON "alert_dashboard" USING GIN (search_vector);

ALTER TABLE "shortener" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(name, '') || ' ' || placeos_fts_uri(uri) || ' ' || COALESCE(description, '') || ' ' ||
    COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_shortener_search_vector ON "shortener" USING GIN (search_vector);

ALTER TABLE "signage_plugin" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    COALESCE(name, '') || ' ' || COALESCE(description, '') || ' ' || placeos_fts_uri(uri) || ' ' ||
    COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_signage_plugin_search_vector ON "signage_plugin" USING GIN (search_vector);

ALTER TABLE "pending_mail" ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (
  to_tsvector('simple',
    placeos_fts_join(template) || ' ' || COALESCE(rejected_reason, '') || ' ' ||
    placeos_fts_email(placeos_fts_join(send_to)) || ' ' || placeos_fts_email(send_from) || ' ' ||
    COALESCE(id::text, '')
  )
) STORED;
CREATE INDEX IF NOT EXISTS idx_pending_mail_search_vector ON "pending_mail" USING GIN (search_vector);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP INDEX IF EXISTS idx_sys_search_vector;
DROP INDEX IF EXISTS idx_mod_search_vector;
DROP INDEX IF EXISTS idx_driver_search_vector;
DROP INDEX IF EXISTS idx_zone_search_vector;
DROP INDEX IF EXISTS idx_user_search_vector;
DROP INDEX IF EXISTS idx_repo_search_vector;
DROP INDEX IF EXISTS idx_trigger_search_vector;
DROP INDEX IF EXISTS idx_authority_search_vector;
DROP INDEX IF EXISTS idx_ldap_strat_search_vector;
DROP INDEX IF EXISTS idx_oauth_strat_search_vector;
DROP INDEX IF EXISTS idx_adfs_strat_search_vector;
DROP INDEX IF EXISTS idx_edge_search_vector;
DROP INDEX IF EXISTS idx_api_key_search_vector;
DROP INDEX IF EXISTS idx_oauth_applications_search_vector;
DROP INDEX IF EXISTS idx_sets_search_vector;
DROP INDEX IF EXISTS idx_json_schema_search_vector;
DROP INDEX IF EXISTS idx_asset_search_vector;
DROP INDEX IF EXISTS idx_asset_type_search_vector;
DROP INDEX IF EXISTS idx_asset_category_search_vector;
DROP INDEX IF EXISTS idx_asset_purchase_order_search_vector;
DROP INDEX IF EXISTS idx_alert_search_vector;
DROP INDEX IF EXISTS idx_alert_dashboard_search_vector;
DROP INDEX IF EXISTS idx_shortener_search_vector;
DROP INDEX IF EXISTS idx_signage_plugin_search_vector;
DROP INDEX IF EXISTS idx_pending_mail_search_vector;

ALTER TABLE "sys" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "mod" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "driver" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "zone" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "user" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "repo" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "trigger" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "authority" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "ldap_strat" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "oauth_strat" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "adfs_strat" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "edge" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "api_key" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "oauth_applications" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "sets" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "json_schema" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "asset" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "asset_type" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "asset_category" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "asset_purchase_order" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "alert" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "alert_dashboard" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "shortener" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "signage_plugin" DROP COLUMN IF EXISTS search_vector;
ALTER TABLE "pending_mail" DROP COLUMN IF EXISTS search_vector;

DROP FUNCTION IF EXISTS placeos_fts_uri(text);
DROP FUNCTION IF EXISTS placeos_fts_email(text);
DROP FUNCTION IF EXISTS placeos_fts_join(text[]);
