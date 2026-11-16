-- +micrate Up
-- Retained independently of History. Actor and credential identifiers deliberately
-- have no foreign keys: deleting those records must not erase this audit trail.
CREATE TABLE IF NOT EXISTS tenancy_reconciliations (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    actor_id TEXT NOT NULL,
    authority_id TEXT NOT NULL,
    api_key_id TEXT,
    idempotency_key TEXT NOT NULL,
    digest TEXT NOT NULL,
    plan JSONB NOT NULL DEFAULT '{}',
    result JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS tenancy_reconciliations_actor_key_unique
    ON tenancy_reconciliations (actor_id, idempotency_key);

-- +micrate Down
DROP TABLE IF EXISTS tenancy_reconciliations;
