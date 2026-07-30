require "json"
require "../base/model"

module PlaceOS::Model
  class AiMaintenanceRun < ModelBase
    table :ai_maintenance_runs

    attribute procedure_id : String, sanitize: :text, es_subfield: "keyword"
    attribute procedure_version : Int32
    attribute procedure_hash : String, sanitize: :text, es_subfield: "keyword"
    attribute schedule_bucket : Int64
    attribute status : String, sanitize: :text, es_subfield: "keyword"
    attribute target_count : Int32 = 0
    attribute incident_ids_json : JSON::Any = JSON::Any.new([] of JSON::Any), sanitize: :common
    attribute classification_counts_json : JSON::Any = JSON::Any.new({} of String => JSON::Any), sanitize: :common
    attribute started_at : Time
    attribute completed_at : Time
    attribute error : String? = nil, sanitize: :common

    validates :procedure_id, :procedure_hash, :status, presence: true
  end
end
