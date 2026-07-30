require "json"
require "../base/model"

module PlaceOS::Model
  class AiApprovalRequest < ModelBase
    include PlaceOS::Model::Timestamps

    table :ai_approval_requests

    attribute incident_id : String, sanitize: :text, es_subfield: "keyword"
    attribute status : String = "pending", sanitize: :text, es_subfield: "keyword"
    attribute requested_by : String, sanitize: :text, es_subfield: "keyword"
    attribute request_note : String? = nil, sanitize: :common
    attribute decided_by : String? = nil, sanitize: :text, es_subfield: "keyword"
    attribute decision_note : String? = nil, sanitize: :common
    attribute proposal_json : JSON::Any = JSON::Any.new({} of String => JSON::Any), sanitize: :common
    attribute execution_mode : String = "approval_only", sanitize: :text, es_subfield: "keyword"
    attribute decided_at : Time? = nil
    attribute executed_at : Time? = nil

    belongs_to AiIncident, foreign_key: "incident_id"

    validates :incident_id, :status, :requested_by, :execution_mode, presence: true
  end
end
