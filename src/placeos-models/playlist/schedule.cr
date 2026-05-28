require "json"
require "cron_parser"

require "../base/model"

# forward declare so this file can be required before playlist.cr finishes
# defining the parent class (the `attribute schedules : Array(Playlist::Schedule)`
# line needs Schedule resolved at macro-expansion time).
class PlaceOS::Model::Playlist < PlaceOS::Model::ModelBase; end

module PlaceOS::Model
  struct Playlist::Schedule
    include JSON::Serializable

    getter play_at : Int64? = nil
    getter play_takeover : Bool = false
    getter play_period : Int32 = 1440
    getter play_cron : String = "0 0 * * *"

    def initialize(
      @play_cron = "0 0 * * *",
      @play_period : Int32 = 1440,
      @play_takeover : Bool = false,
      @play_at : Int64? = nil,
    )
    end

    # `nil` when the schedule is valid, otherwise a human-readable reason.
    def validation_message : String?
      return "play_cron is required" if play_cron.blank?

      begin
        CronParser.new(play_cron)
      rescue error
        return "play_cron invalid: #{error.message}"
      end

      return "play_period must be greater than 0" if play_period < 1

      nil
    end

    def valid? : Bool
      validation_message.nil?
    end
  end
end
