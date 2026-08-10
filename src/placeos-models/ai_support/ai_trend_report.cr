require "json"
require "../base/model"

module PlaceOS::Model
  class AiTrendReport < ModelBase
    table :ai_trend_reports

    attribute policy_id : String, sanitize: :text
    attribute policy_version : Int32
    attribute policy_hash : String, sanitize: :text
    attribute window_start : Time
    attribute window_end : Time
    attribute summary_json : JSON::Any = JSON::Any.new({} of String => JSON::Any), sanitize: :common
    attribute markdown : String, sanitize: :common
    attribute generated_at : Time

    validates :policy_id, :policy_hash, presence: true
  end
end
