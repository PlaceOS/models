require "json"
require "../base/model"

module PlaceOS::Model
  class AiIncidentEvent < ModelWithAutoKey
    table :ai_incident_events

    attribute incident_id : String, sanitize: :text, es_subfield: "keyword"
    attribute source : String, sanitize: :text, es_subfield: "keyword"
    attribute severity : String, sanitize: :text, es_subfield: "keyword"
    attribute correlation_key : String, sanitize: :text, es_subfield: "keyword"
    attribute payload : JSON::Any = JSON::Any.new({} of String => JSON::Any), sanitize: :common
    attribute received_at : Time? = nil

    belongs_to AiIncident, foreign_key: "incident_id"

    validates :incident_id, :source, :severity, :correlation_key, presence: true
  end
end
