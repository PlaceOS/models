require "json"
require "../base/model"

module PlaceOS::Model
  class AiIncidentFeedback < ModelBase
    table :ai_incident_feedback

    attribute incident_id : String, sanitize: :text, es_subfield: "keyword"
    attribute rating : String, sanitize: :text, es_subfield: "keyword"
    attribute submitted_by : String, sanitize: :text, es_subfield: "keyword"
    attribute comment : String? = nil, sanitize: :common
    attribute submitted_at : Time

    belongs_to AiIncident, foreign_key: "incident_id"

    validates :incident_id, :rating, :submitted_by, presence: true
  end
end
