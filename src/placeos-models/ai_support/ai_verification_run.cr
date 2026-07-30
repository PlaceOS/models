require "json"
require "../base/model"

module PlaceOS::Model
  class AiVerificationRun < ModelBase
    table :ai_verification_runs

    attribute incident_id : String, sanitize: :text, es_subfield: "keyword"
    attribute procedure_id : String, sanitize: :text, es_subfield: "keyword"
    attribute procedure_version : Int32
    attribute procedure_hash : String, sanitize: :text, es_subfield: "keyword"
    attribute attempt : Int32
    attribute status : String, sanitize: :text, es_subfield: "keyword"
    attribute checks_json : JSON::Any = JSON::Any.new([] of JSON::Any), sanitize: :common
    attribute evidence_json : JSON::Any = JSON::Any.new([] of JSON::Any), sanitize: :common
    attribute started_at : Time
    attribute completed_at : Time
    attribute next_retry_at : Time? = nil

    belongs_to AiIncident, foreign_key: "incident_id"

    validates :incident_id, :procedure_id, :procedure_hash, :status, presence: true
  end
end
