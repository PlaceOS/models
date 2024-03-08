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

    attribute orientation : Orientation = Orientation::Portrait, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::Playlist::Orientation)
    attribute play_count : Int64 = 0
    attribute play_through_count : Int64 = 0
    attribute default_animation : Animation = Animation::Cut, es_type: "integer", converter: Enum::ValueConverter(PlaceOS::Model::Playlist::Animation)

    attribute random : Bool = false
    attribute enabled : Bool = true

    # time in milliseconds
    attribute default_duration : Int32 = 10_000

    # conditions that can determine when a playlist is valid
    attribute valid_from : Time? = nil, converter: Time::EpochConverter
    attribute valid_until : Time? = nil, converter: Time::EpochConverter

    # hours in the timezone that the playlist should play
    attribute play_hours : String? = nil

    # start playing the playlist at exactly this time or on CRON schedule
    # play_at will ignore timezones
    attribute play_at : Time? = nil, converter: Time::EpochConverter
    attribute play_cron : String? = nil

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

    define_to_json :items, except: :everywhere, methods: :revision

    # Validation
    ###############################################################################################

    validates :name, presence: true
    validates :default_duration, presence: true, numericality: {greater_than: 999}

    # ensure crons valid
    validate ->(this : Playlist) {
      return if (cron = this.play_cron).nil?
      begin
        CronParser.new(cron)
      rescue error
        this.validation_error(:play_cron, "invalid: #{error.message}")
      end
    }
  end
end

require "./playlist/*"
