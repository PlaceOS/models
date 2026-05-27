-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- ---------------------------------------------------------------------------
-- PendingMail: emails queued for later processing/sending. Belongs to an
-- authority and to the user who triggered the mail. `args` carries the JSON
-- scalar values injected into the template. `attachments` /
-- `resource_attachments` hold Upload ids; `zones` holds zone ids. Those id
-- arrays are pruned at the model layer when the referenced upload/zone is
-- deleted (no DB-level FK on array elements).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "pending_mail"(
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    authority_id TEXT NOT NULL REFERENCES "authority"(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,

    expiry TIMESTAMPTZ,

    send_to TEXT[] NOT NULL DEFAULT '{}',
    template TEXT[] NOT NULL DEFAULT '{}',
    args JSONB NOT NULL DEFAULT '{}'::jsonb,

    resource_attachments TEXT[] NOT NULL DEFAULT '{}',
    attachments TEXT[] NOT NULL DEFAULT '{}',

    cc TEXT[] NOT NULL DEFAULT '{}',
    bcc TEXT[] NOT NULL DEFAULT '{}',
    send_from TEXT,
    reply_to TEXT,

    zones TEXT[] NOT NULL DEFAULT '{}',

    -- monitoring fields, populated as the mail is processed
    sent_at TIMESTAMPTZ,
    sent_by TEXT,
    rejected_at TIMESTAMPTZ,
    rejected_reason TEXT,

    -- provenance, indexed for filtering
    source_service TEXT,
    source_reference TEXT,

    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,

    CHECK (jsonb_typeof(args) = 'object')
);

CREATE INDEX IF NOT EXISTS pending_mail_authority_id_index
    ON "pending_mail" USING BTREE (authority_id);
CREATE INDEX IF NOT EXISTS pending_mail_user_id_index
    ON "pending_mail" USING BTREE (user_id);

-- GIN indexes support array containment/overlap lookups used by the
-- upload/zone cleanup callbacks (`'<id>' = ANY(column)`).
CREATE INDEX IF NOT EXISTS pending_mail_attachments_index
    ON "pending_mail" USING GIN (attachments);
CREATE INDEX IF NOT EXISTS pending_mail_resource_attachments_index
    ON "pending_mail" USING GIN (resource_attachments);
CREATE INDEX IF NOT EXISTS pending_mail_zones_index
    ON "pending_mail" USING GIN (zones);

-- provenance lookups for filtering
CREATE INDEX IF NOT EXISTS pending_mail_source_service_index
    ON "pending_mail" USING BTREE (source_service);
CREATE INDEX IF NOT EXISTS pending_mail_source_reference_index
    ON "pending_mail" USING BTREE (source_reference);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP TABLE IF EXISTS "pending_mail";
