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

    # a one-off play time, either as a unix epoch (`play_at`) or as a
    # wall-clock time in the display's local timezone (`play_at_local`, an
    # ISO 8601 string with no offset, e.g. "2027-01-01T00:00:00").
    # These are mutually exclusive.
    getter play_at : Int64? = nil
    getter play_at_local : String? = nil
    getter valid_until : Int64? = nil
    getter valid_from : Int64? = nil
    getter play_takeover : Bool = false
    getter play_period : Int32 = 1440
    getter play_cron : String = "0 0 * * *"

    # bitmask on schedule, requires a valid from date
    # if mask.size > 0 then valid_from is required and mask is considered active
    # max mask size is 128 and string can only contain 0's and 1's
    getter mask : String? = nil

    MAX_MASK_SIZE = 128

    PLAY_AT_LOCAL_FORMAT = "%Y-%m-%dT%H:%M:%S"
    PLAY_AT_LOCAL_REGEX  = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\z/

    def initialize(
      @play_cron = "0 0 * * *",
      @play_period : Int32 = 1440,
      @play_takeover : Bool = false,
      @play_at : Int64? = nil,
      @play_at_local : String? = nil,
      @valid_until : Int64? = nil,
      @valid_from : Int64? = nil,
      @mask : String? = nil,
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

      if local = play_at_local
        return "only one of play_at or play_at_local can be set" if play_at
        return "play_at_local must be an ISO 8601 date time with no offset, e.g. 2027-01-01T00:00:00" unless valid_local_time?(local)
      end

      if (starting = valid_from) && (ending = valid_until) && ending <= starting
        return "valid_until must be greater than valid_from"
      end

      if (bits = mask) && !bits.empty?
        return "mask must not exceed #{MAX_MASK_SIZE} characters" if bits.size > MAX_MASK_SIZE
        return "mask can only contain 0's and 1's" unless bits.each_char.all?(&.in?('0', '1'))
        return "valid_from is required when mask is set" if valid_from.nil?
      end

      nil
    end

    def valid? : Bool
      validation_message.nil?
    end

    # the regex enforces the exact shape (no offset, fractions or single
    # digit fields). Parsing rejects most out of range values, but hour 24
    # silently rolls over to the next day, so the result must round-trip.
    private def valid_local_time?(value : String) : Bool
      return false unless PLAY_AT_LOCAL_REGEX.matches?(value)
      Time.parse(value, PLAY_AT_LOCAL_FORMAT, Time::Location::UTC).to_s(PLAY_AT_LOCAL_FORMAT) == value
    rescue ArgumentError | Time::Format::Error
      false
    end
  end
end
