require "json"
require "../base/model"

module PlaceOS::Model
  class AiCorrelationFinding < ModelBase
    table :ai_correlation_findings

    attribute deduplication_key : String, sanitize: :text
    attribute kind : String, sanitize: :text
    attribute policy_id : String, sanitize: :text
    attribute policy_version : Int32
    attribute policy_hash : String, sanitize: :text
    attribute scope_key : String, sanitize: :text
    attribute tenant_id : String? = nil, sanitize: :text
    attribute system_id : String? = nil, sanitize: :text
    attribute module_id : String? = nil, sanitize: :text
    attribute classification : String, sanitize: :text
    attribute incident_ids_json : JSON::Any = JSON::Any.new([] of JSON::Any), sanitize: :common
    attribute observation_count : Int32
    attribute transition_count : Int32
    attribute window_start : Time
    attribute window_end : Time
    attribute summary : String, sanitize: :common
    attribute detected_at : Time

    validates :deduplication_key, :kind, :policy_id, :policy_hash, :scope_key, :classification, presence: true
  end
end
