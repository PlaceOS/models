require "cron_parser"
require "./base/model"
require "./upload"
require "./control_system"
require "./zone"

module PlaceOS::Model
  class Playlist < ModelBase
    include PlaceOS::Model::Timestamps

    enum Orientation
      Unspecified
      Landscape
      Portrait
      Square
    end

    enum Animation
      Default
      Cut
      CrossFade
      SlideTop
      SlideLeft
      SlideRight
      SlideBottom
    end

    table :playlists

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""

    belongs_to Authority, foreign_key: "authority_id"

    attribute orientation : Orientation = Orientation::Portrait, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::Playlist::Orientation)
    attribute play_count : Int64 = 0
    attribute play_through_count : Int64 = 0
    attribute default_animation : Animation = Animation::Cut, es_type: "integer", converter: Enum::ValueConverter(PlaceOS::Model::Playlist::Animation)

    attribute random : Bool = false
    attribute enabled : Bool = true

    # time in milliseconds
    attribute default_duration : Int32 = 10_000

    # conditions that can determine when a playlist is valid
    attribute valid_from : Int64? = nil
    attribute valid_until : Int64? = nil

    # hours in the timezone that the playlist should play
    attribute play_hours : String? = nil

    # start playing the playlist at exactly this time or on CRON schedule
    # play_at will ignore timezones
    attribute play_at : Int64? = nil
    attribute play_cron : String? = nil

    def should_present?(now : Time = Time.utc, timezone : Bool = false) : Bool
      return false unless enabled

      now_unix = now.to_unix
      starting = valid_from
      ending = valid_until
      return false if starting && starting > now_unix
      return false if ending && ending <= now_unix

      if timezone && (hours = play_hours)
        return between?(hours, now)
      end

      true
    end

    def between?(times : String, now : Time) : Bool
      start_str, end_str = times.split('-', 2)

      # Parse hours/minutes manually (faster + avoids timezone parsing issues)
      start_hour = start_str[0, 2].to_i
      start_min = start_str[3, 2].to_i
      end_hour = end_str[0, 2].to_i
      end_min = end_str[3, 2].to_i

      now_minutes =
        now.hour * 60 + now.minute

      start_minutes =
        start_hour * 60 + start_min

      end_minutes =
        end_hour * 60 + end_min

      if start_minutes <= end_minutes
        # Normal range (same day)
        now_minutes >= start_minutes && now_minutes < end_minutes
      else
        # Overnight range (crosses midnight)
        now_minutes >= start_minutes || now_minutes < end_minutes
      end
    end

    def systems
      ControlSystem.with_playlists({self.id.as(String)})
    end

    def zones
      Zone.with_playlists({self.id.as(String)})
    end

    def revisions
      Playlist::Revision.where(playlist_id: self.id).order(created_at: :desc)
    end

    def revision
      revisions.first
    end

    def self.update_counts(metrics : Hash(String, Int32))
      update_count_field("play_count", metrics)
    end

    def self.update_through_counts(metrics : Hash(String, Int32))
      update_count_field("play_through_count", metrics)
    end

    protected def self.update_count_field(field : String, metrics : Hash(String, Int32)) : Int64
      return 0_i64 if metrics.empty?

      metrics = metrics.transform_keys(&.gsub("'", "''"))

      update_item_counts = String.build do |str|
        str << %[
          UPDATE playlists
          SET #{field} = #{field} + CASE id
        ]

        metrics.each do |key, count|
          # WHEN 'id2' THEN 5
          str << "\nWHEN '"
          str << key.gsub("'", "''")
          str << "' THEN "
          count.to_s(str)
        end

        str << %[\nELSE 0
          END
          WHERE id IN ('#{metrics.keys.join("', '")}')
        ]
      end

      response = ::PgORM::Database.connection do |db|
        db.exec(update_item_counts)
      end
      response.rows_affected
    end

    define_to_json :items, except: :everywhere, methods: :revision

    # Validation
    ###############################################################################################

    validates :name, presence: true
    validates :default_duration, presence: true, numericality: {greater_than: 999}

    # valid format:
    validates :play_hours, format: {
      :message => "must be in the form: 10:30-16:00",
      :with    => /\A(?:[01]\d|2[0-3]):[0-5]\d-(?:[01]\d|2[0-3]):[0-5]\d\z/,
    }

    # ensure crons valid
    validate ->(this : Playlist) {
      if (cron = this.play_cron.presence).nil?
        this.play_cron = nil
        return
      end

      begin
        CronParser.new(cron)
      rescue error
        this.validation_error(:play_cron, "invalid: #{error.message}")
      end
    }
  end
end

require "./playlist/*"
