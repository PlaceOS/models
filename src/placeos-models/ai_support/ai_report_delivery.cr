require "json"
require "../base/model"

module PlaceOS::Model
  class AiReportDelivery < ModelWithAutoKey
    table :ai_report_deliveries

    attribute incident_id : String, sanitize: :text
    attribute status : String, sanitize: :text
    attribute destination : String, sanitize: :text
    attribute attempted_at : Time
    attribute response_status : Int32? = nil
    attribute error : String? = nil, sanitize: :common

    belongs_to AiIncident, foreign_key: "incident_id"

    validates :incident_id, :status, :destination, presence: true
  end
end
