-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- Provider rows hold the vendor credentials used to generate signage artwork.
-- A row with a NULL authority_id is the shared fallback, mirroring "storages".
CREATE TABLE IF NOT EXISTS "signage_ai_providers" (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  authority_id TEXT,
  name TEXT NOT NULL,
  provider TEXT NOT NULL,

  -- encrypted JSON object: api key, or Azure resource details, or a service account
  credentials TEXT NOT NULL,
  endpoint TEXT,
  location TEXT,
  default_model TEXT,
  allowed_models TEXT[] NOT NULL DEFAULT '{}'::TEXT[],

  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,

  -- {"user_per_day": 60, "domain_per_month": 2000}
  quotas JSONB NOT NULL DEFAULT '{}'::jsonb,

  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,

  CONSTRAINT signage_ai_providers_provider_check
    CHECK (provider IN ('OPENAI', 'AZURE_OPENAI', 'GOOGLE_VERTEX')),
  CONSTRAINT signage_ai_providers_quotas_check
    CHECK (jsonb_typeof(quotas) = 'object'),
  FOREIGN KEY (authority_id) REFERENCES authority(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS signage_ai_providers_authority_id_index
  ON "signage_ai_providers" USING BTREE (authority_id);

CREATE UNIQUE INDEX IF NOT EXISTS signage_ai_providers_authority_name_idx
  ON "signage_ai_providers" (authority_id, name)
  NULLS NOT DISTINCT;

CREATE UNIQUE INDEX IF NOT EXISTS signage_ai_providers_authority_default_idx
  ON "signage_ai_providers" (authority_id)
  NULLS NOT DISTINCT
  WHERE is_default = TRUE;

-- +micrate StatementBegin
-- Only one default provider per authority; flip the others back to FALSE.
CREATE OR REPLACE FUNCTION signage_ai_providers_ensure_single_default()
  RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_default THEN
    UPDATE signage_ai_providers
      SET is_default = FALSE
    WHERE authority_id IS NOT DISTINCT FROM NEW.authority_id
      AND id <> NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- +micrate StatementEnd

DROP TRIGGER IF EXISTS trg_signage_ai_providers_single_default ON signage_ai_providers;

CREATE TRIGGER trg_signage_ai_providers_single_default
  BEFORE INSERT OR UPDATE OF is_default
  ON signage_ai_providers
  FOR EACH ROW
  WHEN (NEW.is_default = TRUE)
  EXECUTE FUNCTION signage_ai_providers_ensure_single_default();

-- One row per generate or edit request. Candidate images are written into
-- result->'images' one at a time by the runner, bumping "version" each write so a
-- long polling client can tell what it has already seen.
CREATE TABLE IF NOT EXISTS "signage_ai_jobs" (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  authority_id TEXT NOT NULL,
  provider_id UUID,
  provider_type TEXT,
  model TEXT,

  user_id TEXT,
  user_email TEXT,
  user_name TEXT,

  -- a refine points at the job it was refined from
  parent_job_id UUID,

  version INTEGER NOT NULL DEFAULT 0,
  kind TEXT NOT NULL,
  state TEXT NOT NULL DEFAULT 'QUEUED',
  cancel_requested BOOLEAN NOT NULL DEFAULT FALSE,
  idempotency_key TEXT,

  candidates INTEGER NOT NULL DEFAULT 1,
  images_produced INTEGER NOT NULL DEFAULT 0,

  prompt TEXT,
  request JSONB NOT NULL DEFAULT '{}'::jsonb,
  result JSONB NOT NULL DEFAULT '{}'::jsonb,

  error_kind TEXT,
  error_message TEXT,
  upload_ids TEXT[] NOT NULL DEFAULT '{}'::TEXT[],

  cost_units DOUBLE PRECISION,
  latency_ms BIGINT,

  started_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,

  CONSTRAINT signage_ai_jobs_kind_check
    CHECK (kind IN ('GENERATE', 'EDIT')),
  CONSTRAINT signage_ai_jobs_state_check
    CHECK (state IN ('QUEUED', 'RUNNING', 'DONE', 'FAILED', 'CANCELLED')),
  CONSTRAINT signage_ai_jobs_request_check
    CHECK (jsonb_typeof(request) = 'object'),
  CONSTRAINT signage_ai_jobs_result_check
    CHECK (jsonb_typeof(result) = 'object'),
  FOREIGN KEY (authority_id) REFERENCES authority(id) ON DELETE CASCADE,
  FOREIGN KEY (provider_id) REFERENCES signage_ai_providers(id) ON DELETE SET NULL,
  FOREIGN KEY (user_id) REFERENCES "user"(id) ON DELETE SET NULL,
  FOREIGN KEY (parent_job_id) REFERENCES signage_ai_jobs(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS signage_ai_jobs_authority_id_index
  ON "signage_ai_jobs" USING BTREE (authority_id);
CREATE INDEX IF NOT EXISTS signage_ai_jobs_state_index
  ON "signage_ai_jobs" USING BTREE (state);
CREATE INDEX IF NOT EXISTS signage_ai_jobs_created_at_index
  ON "signage_ai_jobs" USING BTREE (created_at);
CREATE INDEX IF NOT EXISTS signage_ai_jobs_user_created_index
  ON "signage_ai_jobs" USING BTREE (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS signage_ai_jobs_parent_job_id_index
  ON "signage_ai_jobs" USING BTREE (parent_job_id);

-- a repeated submission with the same key returns the job that already exists
CREATE UNIQUE INDEX IF NOT EXISTS signage_ai_jobs_idempotency_idx
  ON "signage_ai_jobs" (user_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP TABLE IF EXISTS "signage_ai_jobs";

DROP TRIGGER IF EXISTS trg_signage_ai_providers_single_default ON signage_ai_providers;
DROP FUNCTION IF EXISTS signage_ai_providers_ensure_single_default() CASCADE;
DROP TABLE IF EXISTS "signage_ai_providers";
