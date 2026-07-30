require "json"
require "../base/model"

module PlaceOS::Model
  class AiAgentRun < ModelWithAutoKey
    table :ai_agent_runs

    attribute incident_id : String, sanitize: :text, es_subfield: "keyword"
    attribute correlation_key : String, sanitize: :text, es_subfield: "keyword"
    attribute classification : String, sanitize: :text, es_subfield: "keyword"
    attribute confidence : Float64 = 0.0
    attribute plan_json : JSON::Any? = nil, sanitize: :common
    attribute investigation_json : JSON::Any = JSON::Any.new([] of JSON::Any), sanitize: :common
    attribute decision_json : JSON::Any? = nil, sanitize: :common
    attribute remediation_proposal_json : JSON::Any? = nil, sanitize: :common

    belongs_to AiIncident, foreign_key: "incident_id"

    validates :incident_id, :correlation_key, :classification, presence: true
  end
end
