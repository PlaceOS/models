require "time"
require "./base/model"

module PlaceOS::Model
  class WorkingFromHome < ModelBase
    table :working_from_home

    attribute start_time : Int64
    attribute end_time : Int64
    attribute user_id : String, es_type: "keyword"

    belongs_to User, foreign_key: "user_id", association_name: "user"

    validates :start_time, :end_time, :user_id, presence: true

    record Preference, day : Time::DayOfWeek, start_time : Int64, end_time : Int64 do
      include JSON::Serializable
    end
  end
end
