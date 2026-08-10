require "json"
require "../base/model"

module PlaceOS::Model
  class AiIncidentReport < ModelWithAutoKey
    table :ai_incident_reports

    attribute incident_id : String, sanitize: :text
    attribute report_schema_version : String = "incident-report.v1", sanitize: :text
    attribute status : String, sanitize: :text
    attribute classification : String, sanitize: :text
    attribute confidence : Float64 = 0.0
    attribute report_json : JSON::Any = JSON::Any.new({} of String => JSON::Any), sanitize: :common
    attribute evidence_json : JSON::Any = JSON::Any.new([] of JSON::Any), sanitize: :common
    attribute investigation_json : JSON::Any = JSON::Any.new([] of JSON::Any), sanitize: :common
    attribute decision_json : JSON::Any? = nil, sanitize: :common
    attribute markdown : String? = nil, sanitize: :common

    belongs_to AiIncident, foreign_key: "incident_id"

    validates :incident_id, :report_schema_version, :status, :classification, presence: true
  end
end
