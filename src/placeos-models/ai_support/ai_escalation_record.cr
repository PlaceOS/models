require "json"
require "../base/model"

module PlaceOS::Model
  class AiEscalationRecord < ModelBase
    table :ai_escalation_records

    attribute incident_id : String, sanitize: :text, es_subfield: "keyword"
    attribute procedure_id : String, sanitize: :text, es_subfield: "keyword"
    attribute procedure_version : Int32
    attribute procedure_hash : String, sanitize: :text, es_subfield: "keyword"
    attribute owner_queue : String, sanitize: :text, es_subfield: "keyword"
    attribute response_sla_minutes : Int32
    attribute reason : String, sanitize: :common
    attribute required_artefacts_json : JSON::Any = JSON::Any.new([] of JSON::Any), sanitize: :common
    attribute delivery_status : String, sanitize: :text, es_subfield: "keyword"
    attribute delivery_destination : String, sanitize: :text, es_subfield: "keyword"
    attribute delivery_error : String? = nil, sanitize: :common
    attribute response_due_at : Time
    attribute escalated_at : Time

    belongs_to AiIncident, foreign_key: "incident_id"

    validates :incident_id, :procedure_id, :procedure_hash, :owner_queue, :delivery_status, presence: true
  end
end
