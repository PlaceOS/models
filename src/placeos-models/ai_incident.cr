require "json"
require "./base/model"
require "./ai_support/**"

module PlaceOS::Model
  class AiIncident < ModelBase
    include PlaceOS::Model::Timestamps

    table :ai_incidents

    attribute status : String = "open", sanitize: :text
    attribute severity : String = "info", sanitize: :text
    attribute source : String = "webhook", sanitize: :text
    attribute classification : String = "unknown", sanitize: :text
    attribute confidence : Float64 = 0.0
    attribute summary : String = "", sanitize: :common
    attribute correlation_key : String, sanitize: :text
    attribute report_schema_version : String = "incident-report.v1", sanitize: :text

    attribute tenant_id : String? = nil, sanitize: :text
    attribute system_id : String? = nil, sanitize: :text
    attribute module_id : String? = nil, sanitize: :text
    attribute module_name : String? = nil, sanitize: :common
    attribute module_index : Int32? = nil

    attribute duplicate_count : Int32 = 0
    attribute last_seen_at : Time? = nil
    attribute resolved_at : Time? = nil
    attribute claim_token : String? = nil, sanitize: :text
    attribute claim_expires_at : Time? = nil

    has_many(
      child_class: AiIncidentEvent,
      dependent: :destroy,
      foreign_key: "incident_id",
      collection_name: :events
    )

    has_many(
      child_class: AiIncidentReport,
      dependent: :destroy,
      foreign_key: "incident_id",
      collection_name: :reports
    )

    has_many(
      child_class: AiAgentRun,
      dependent: :destroy,
      foreign_key: "incident_id",
      collection_name: :agent_runs
    )

    has_many(
      child_class: AiApprovalRequest,
      dependent: :destroy,
      foreign_key: "incident_id",
      collection_name: :approval_requests
    )

    has_many(
      child_class: AiReportDelivery,
      dependent: :destroy,
      foreign_key: "incident_id",
      collection_name: :report_deliveries
    )

    has_many(
      child_class: AiVerificationRun,
      dependent: :destroy,
      foreign_key: "incident_id",
      collection_name: :verification_runs
    )

    has_many(
      child_class: AiEscalationRecord,
      dependent: :destroy,
      foreign_key: "incident_id",
      collection_name: :escalation_records
    )

    has_many(
      child_class: AiIncidentFeedback,
      dependent: :destroy,
      foreign_key: "incident_id",
      collection_name: :feedback
    )

    validates :status, :severity, :source, :classification, :correlation_key, presence: true
  end
end
