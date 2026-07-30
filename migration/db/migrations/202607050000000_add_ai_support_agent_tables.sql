-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

CREATE TABLE IF NOT EXISTS "ai_incidents" (
    id TEXT NOT NULL PRIMARY KEY,
    status TEXT NOT NULL,
    severity TEXT NOT NULL,
    source TEXT NOT NULL,
    classification TEXT NOT NULL,
    confidence DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    summary TEXT NOT NULL DEFAULT '',
    correlation_key TEXT NOT NULL,
    report_schema_version TEXT NOT NULL DEFAULT 'incident-report.v1',
    tenant_id TEXT,
    system_id TEXT,
    module_id TEXT,
    module_name TEXT,
    module_index INTEGER,
    duplicate_count INTEGER NOT NULL DEFAULT 0,
    last_seen_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    claim_token TEXT,
    claim_expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT ai_incidents_claim_state_check CHECK (
        (status = 'investigating' AND claim_token IS NOT NULL AND claim_expires_at IS NOT NULL)
        OR
        (status <> 'investigating' AND claim_token IS NULL AND claim_expires_at IS NULL)
    )
);

CREATE INDEX IF NOT EXISTS ai_incidents_correlation_key_index ON "ai_incidents" USING BTREE (correlation_key);
CREATE UNIQUE INDEX IF NOT EXISTS ai_incidents_active_correlation_key_index ON "ai_incidents" USING BTREE (correlation_key) WHERE resolved_at IS NULL;
CREATE INDEX IF NOT EXISTS ai_incidents_status_index ON "ai_incidents" USING BTREE (status);
CREATE INDEX IF NOT EXISTS ai_incidents_tenant_id_index ON "ai_incidents" USING BTREE (tenant_id);
CREATE INDEX IF NOT EXISTS ai_incidents_system_id_index ON "ai_incidents" USING BTREE (system_id);
CREATE INDEX IF NOT EXISTS ai_incidents_module_id_index ON "ai_incidents" USING BTREE (module_id);
CREATE INDEX IF NOT EXISTS ai_incidents_created_at_index ON "ai_incidents" USING BTREE (created_at);
CREATE INDEX IF NOT EXISTS ai_incidents_last_seen_at_index ON "ai_incidents" USING BTREE (last_seen_at);
CREATE INDEX IF NOT EXISTS ai_incidents_resolved_at_index ON "ai_incidents" USING BTREE (resolved_at);
CREATE INDEX IF NOT EXISTS ai_incidents_claim_expires_at_index ON "ai_incidents" USING BTREE (claim_expires_at) WHERE status = 'investigating';

CREATE TABLE IF NOT EXISTS "ai_incident_events" (
    id bigint PRIMARY KEY,
    incident_id TEXT NOT NULL,
    source TEXT NOT NULL,
    severity TEXT NOT NULL,
    correlation_key TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    received_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE SEQUENCE IF NOT EXISTS public.ai_incident_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.ai_incident_events_id_seq OWNED BY "ai_incident_events".id;
ALTER TABLE ONLY "ai_incident_events" ALTER COLUMN id SET DEFAULT nextval('public.ai_incident_events_id_seq'::regclass);

CREATE INDEX IF NOT EXISTS ai_incident_events_incident_id_index ON "ai_incident_events" USING BTREE (incident_id);
CREATE INDEX IF NOT EXISTS ai_incident_events_correlation_key_index ON "ai_incident_events" USING BTREE (correlation_key);
CREATE INDEX IF NOT EXISTS ai_incident_events_received_at_index ON "ai_incident_events" USING BTREE (received_at);
CREATE INDEX IF NOT EXISTS ai_incident_events_payload_index ON "ai_incident_events" USING GIN (payload jsonb_path_ops);

CREATE TABLE IF NOT EXISTS "ai_incident_reports" (
    id bigint PRIMARY KEY,
    incident_id TEXT NOT NULL,
    report_schema_version TEXT NOT NULL DEFAULT 'incident-report.v1',
    status TEXT NOT NULL,
    classification TEXT NOT NULL,
    confidence DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    report_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    evidence_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    investigation_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    decision_json JSONB,
    markdown TEXT,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE SEQUENCE IF NOT EXISTS public.ai_incident_reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.ai_incident_reports_id_seq OWNED BY "ai_incident_reports".id;
ALTER TABLE ONLY "ai_incident_reports" ALTER COLUMN id SET DEFAULT nextval('public.ai_incident_reports_id_seq'::regclass);

CREATE INDEX IF NOT EXISTS ai_incident_reports_incident_id_index ON "ai_incident_reports" USING BTREE (incident_id);
CREATE INDEX IF NOT EXISTS ai_incident_reports_status_index ON "ai_incident_reports" USING BTREE (status);
CREATE INDEX IF NOT EXISTS ai_incident_reports_classification_index ON "ai_incident_reports" USING BTREE (classification);
CREATE INDEX IF NOT EXISTS ai_incident_reports_created_at_index ON "ai_incident_reports" USING BTREE (created_at);
CREATE INDEX IF NOT EXISTS ai_incident_reports_report_json_index ON "ai_incident_reports" USING GIN (report_json jsonb_path_ops);

CREATE TABLE IF NOT EXISTS "ai_agent_runs" (
    id bigint PRIMARY KEY,
    incident_id TEXT NOT NULL,
    correlation_key TEXT NOT NULL,
    classification TEXT NOT NULL,
    confidence DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    plan_json JSONB,
    investigation_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    decision_json JSONB,
    remediation_proposal_json JSONB,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE SEQUENCE IF NOT EXISTS public.ai_agent_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.ai_agent_runs_id_seq OWNED BY "ai_agent_runs".id;
ALTER TABLE ONLY "ai_agent_runs" ALTER COLUMN id SET DEFAULT nextval('public.ai_agent_runs_id_seq'::regclass);

CREATE INDEX IF NOT EXISTS ai_agent_runs_incident_id_index ON "ai_agent_runs" USING BTREE (incident_id);
CREATE INDEX IF NOT EXISTS ai_agent_runs_correlation_key_index ON "ai_agent_runs" USING BTREE (correlation_key);
CREATE INDEX IF NOT EXISTS ai_agent_runs_classification_index ON "ai_agent_runs" USING BTREE (classification);

CREATE TABLE IF NOT EXISTS "ai_approval_requests" (
    id TEXT NOT NULL PRIMARY KEY,
    incident_id TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    requested_by TEXT NOT NULL,
    request_note TEXT,
    decided_by TEXT,
    decision_note TEXT,
    proposal_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    execution_mode TEXT NOT NULL DEFAULT 'approval_only',
    decided_at TIMESTAMPTZ,
    executed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS ai_approval_requests_incident_id_index ON "ai_approval_requests" USING BTREE (incident_id);
CREATE INDEX IF NOT EXISTS ai_approval_requests_status_index ON "ai_approval_requests" USING BTREE (status);
CREATE INDEX IF NOT EXISTS ai_approval_requests_requested_by_index ON "ai_approval_requests" USING BTREE (requested_by);
CREATE INDEX IF NOT EXISTS ai_approval_requests_created_at_index ON "ai_approval_requests" USING BTREE (created_at);
CREATE INDEX IF NOT EXISTS ai_approval_requests_proposal_json_index ON "ai_approval_requests" USING GIN (proposal_json jsonb_path_ops);

CREATE TABLE IF NOT EXISTS "ai_report_deliveries" (
    id bigint PRIMARY KEY,
    incident_id TEXT NOT NULL,
    status TEXT NOT NULL,
    destination TEXT NOT NULL,
    attempted_at TIMESTAMPTZ NOT NULL,
    response_status INTEGER,
    error TEXT,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE SEQUENCE IF NOT EXISTS public.ai_report_deliveries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.ai_report_deliveries_id_seq OWNED BY "ai_report_deliveries".id;
ALTER TABLE ONLY "ai_report_deliveries" ALTER COLUMN id SET DEFAULT nextval('public.ai_report_deliveries_id_seq'::regclass);

CREATE INDEX IF NOT EXISTS ai_report_deliveries_incident_id_index ON "ai_report_deliveries" USING BTREE (incident_id);
CREATE INDEX IF NOT EXISTS ai_report_deliveries_status_index ON "ai_report_deliveries" USING BTREE (status);
CREATE INDEX IF NOT EXISTS ai_report_deliveries_destination_index ON "ai_report_deliveries" USING BTREE (destination);
CREATE INDEX IF NOT EXISTS ai_report_deliveries_attempted_at_index ON "ai_report_deliveries" USING BTREE (attempted_at);

CREATE TABLE IF NOT EXISTS "ai_verification_runs" (
    id TEXT NOT NULL PRIMARY KEY,
    incident_id TEXT NOT NULL,
    procedure_id TEXT NOT NULL,
    procedure_version INTEGER NOT NULL,
    procedure_hash TEXT NOT NULL,
    attempt INTEGER NOT NULL,
    status TEXT NOT NULL,
    checks_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    evidence_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ NOT NULL,
    next_retry_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS ai_verification_runs_incident_id_index ON "ai_verification_runs" USING BTREE (incident_id);
CREATE INDEX IF NOT EXISTS ai_verification_runs_status_index ON "ai_verification_runs" USING BTREE (status);
CREATE INDEX IF NOT EXISTS ai_verification_runs_procedure_id_index ON "ai_verification_runs" USING BTREE (procedure_id);
CREATE INDEX IF NOT EXISTS ai_verification_runs_started_at_index ON "ai_verification_runs" USING BTREE (started_at);
CREATE INDEX IF NOT EXISTS ai_verification_runs_next_retry_at_index ON "ai_verification_runs" USING BTREE (next_retry_at);

CREATE TABLE IF NOT EXISTS "ai_escalation_records" (
    id TEXT NOT NULL PRIMARY KEY,
    incident_id TEXT NOT NULL,
    procedure_id TEXT NOT NULL,
    procedure_version INTEGER NOT NULL,
    procedure_hash TEXT NOT NULL,
    owner_queue TEXT NOT NULL,
    response_sla_minutes INTEGER NOT NULL,
    reason TEXT NOT NULL,
    required_artefacts_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    delivery_status TEXT NOT NULL,
    delivery_destination TEXT NOT NULL,
    delivery_error TEXT,
    response_due_at TIMESTAMPTZ NOT NULL,
    escalated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS ai_escalation_records_incident_id_index ON "ai_escalation_records" USING BTREE (incident_id);
CREATE INDEX IF NOT EXISTS ai_escalation_records_owner_queue_index ON "ai_escalation_records" USING BTREE (owner_queue);
CREATE INDEX IF NOT EXISTS ai_escalation_records_delivery_status_index ON "ai_escalation_records" USING BTREE (delivery_status);
CREATE INDEX IF NOT EXISTS ai_escalation_records_response_due_at_index ON "ai_escalation_records" USING BTREE (response_due_at);

CREATE TABLE IF NOT EXISTS "ai_maintenance_runs" (
    id TEXT NOT NULL PRIMARY KEY,
    procedure_id TEXT NOT NULL,
    procedure_version INTEGER NOT NULL,
    procedure_hash TEXT NOT NULL,
    schedule_bucket BIGINT NOT NULL,
    status TEXT NOT NULL,
    target_count INTEGER NOT NULL DEFAULT 0,
    incident_ids_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    classification_counts_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ NOT NULL,
    error TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS ai_maintenance_runs_window_index ON "ai_maintenance_runs" USING BTREE (procedure_id, procedure_version, schedule_bucket);
CREATE INDEX IF NOT EXISTS ai_maintenance_runs_status_index ON "ai_maintenance_runs" USING BTREE (status);
CREATE INDEX IF NOT EXISTS ai_maintenance_runs_started_at_index ON "ai_maintenance_runs" USING BTREE (started_at);

CREATE TABLE IF NOT EXISTS "ai_correlation_findings" (
    id TEXT NOT NULL PRIMARY KEY,
    deduplication_key TEXT NOT NULL,
    kind TEXT NOT NULL,
    policy_id TEXT NOT NULL,
    policy_version INTEGER NOT NULL,
    policy_hash TEXT NOT NULL,
    scope_key TEXT NOT NULL,
    tenant_id TEXT,
    system_id TEXT,
    module_id TEXT,
    classification TEXT NOT NULL,
    incident_ids_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    observation_count INTEGER NOT NULL,
    transition_count INTEGER NOT NULL,
    window_start TIMESTAMPTZ NOT NULL,
    window_end TIMESTAMPTZ NOT NULL,
    summary TEXT NOT NULL,
    detected_at TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS ai_correlation_findings_deduplication_key_index ON "ai_correlation_findings" USING BTREE (deduplication_key);
CREATE INDEX IF NOT EXISTS ai_correlation_findings_kind_index ON "ai_correlation_findings" USING BTREE (kind);
CREATE INDEX IF NOT EXISTS ai_correlation_findings_scope_key_index ON "ai_correlation_findings" USING BTREE (scope_key);
CREATE INDEX IF NOT EXISTS ai_correlation_findings_window_start_index ON "ai_correlation_findings" USING BTREE (window_start);

CREATE TABLE IF NOT EXISTS "ai_incident_feedback" (
    id TEXT NOT NULL PRIMARY KEY,
    incident_id TEXT NOT NULL,
    rating TEXT NOT NULL,
    submitted_by TEXT NOT NULL,
    comment TEXT,
    submitted_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS ai_incident_feedback_incident_id_index ON "ai_incident_feedback" USING BTREE (incident_id);
CREATE INDEX IF NOT EXISTS ai_incident_feedback_rating_index ON "ai_incident_feedback" USING BTREE (rating);
CREATE INDEX IF NOT EXISTS ai_incident_feedback_submitted_at_index ON "ai_incident_feedback" USING BTREE (submitted_at);

CREATE TABLE IF NOT EXISTS "ai_trend_reports" (
    id TEXT NOT NULL PRIMARY KEY,
    policy_id TEXT NOT NULL,
    policy_version INTEGER NOT NULL,
    policy_hash TEXT NOT NULL,
    window_start TIMESTAMPTZ NOT NULL,
    window_end TIMESTAMPTZ NOT NULL,
    summary_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    markdown TEXT NOT NULL,
    generated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS ai_trend_reports_generated_at_index ON "ai_trend_reports" USING BTREE (generated_at);
CREATE INDEX IF NOT EXISTS ai_trend_reports_policy_id_index ON "ai_trend_reports" USING BTREE (policy_id);

ALTER TABLE ONLY "ai_incident_events"
    DROP CONSTRAINT IF EXISTS ai_incident_events_incident_id_fkey;
ALTER TABLE ONLY "ai_incident_events"
    ADD CONSTRAINT ai_incident_events_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES "ai_incidents"(id) ON DELETE CASCADE;

ALTER TABLE ONLY "ai_incident_reports"
    DROP CONSTRAINT IF EXISTS ai_incident_reports_incident_id_fkey;
ALTER TABLE ONLY "ai_incident_reports"
    ADD CONSTRAINT ai_incident_reports_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES "ai_incidents"(id) ON DELETE CASCADE;

ALTER TABLE ONLY "ai_agent_runs"
    DROP CONSTRAINT IF EXISTS ai_agent_runs_incident_id_fkey;
ALTER TABLE ONLY "ai_agent_runs"
    ADD CONSTRAINT ai_agent_runs_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES "ai_incidents"(id) ON DELETE CASCADE;

ALTER TABLE ONLY "ai_approval_requests"
    DROP CONSTRAINT IF EXISTS ai_approval_requests_incident_id_fkey;
ALTER TABLE ONLY "ai_approval_requests"
    ADD CONSTRAINT ai_approval_requests_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES "ai_incidents"(id) ON DELETE CASCADE;

ALTER TABLE ONLY "ai_report_deliveries"
    DROP CONSTRAINT IF EXISTS ai_report_deliveries_incident_id_fkey;
ALTER TABLE ONLY "ai_report_deliveries"
    ADD CONSTRAINT ai_report_deliveries_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES "ai_incidents"(id) ON DELETE CASCADE;

ALTER TABLE ONLY "ai_verification_runs"
    DROP CONSTRAINT IF EXISTS ai_verification_runs_incident_id_fkey;
ALTER TABLE ONLY "ai_verification_runs"
    ADD CONSTRAINT ai_verification_runs_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES "ai_incidents"(id) ON DELETE CASCADE;

ALTER TABLE ONLY "ai_escalation_records"
    DROP CONSTRAINT IF EXISTS ai_escalation_records_incident_id_fkey;
ALTER TABLE ONLY "ai_escalation_records"
    ADD CONSTRAINT ai_escalation_records_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES "ai_incidents"(id) ON DELETE CASCADE;

ALTER TABLE ONLY "ai_incident_feedback"
    DROP CONSTRAINT IF EXISTS ai_incident_feedback_incident_id_fkey;
ALTER TABLE ONLY "ai_incident_feedback"
    ADD CONSTRAINT ai_incident_feedback_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES "ai_incidents"(id) ON DELETE CASCADE;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP TABLE IF EXISTS "ai_trend_reports";
DROP TABLE IF EXISTS "ai_incident_feedback";
DROP TABLE IF EXISTS "ai_correlation_findings";
DROP TABLE IF EXISTS "ai_maintenance_runs";
DROP TABLE IF EXISTS "ai_escalation_records";
DROP TABLE IF EXISTS "ai_verification_runs";
DROP TABLE IF EXISTS "ai_report_deliveries";
DROP TABLE IF EXISTS "ai_approval_requests";
DROP TABLE IF EXISTS "ai_agent_runs";
DROP TABLE IF EXISTS "ai_incident_reports";
DROP TABLE IF EXISTS "ai_incident_events";
DROP TABLE IF EXISTS "ai_incidents";
