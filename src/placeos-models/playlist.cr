require "./base/model"
require "./upload"
require "./control_system"
require "./zone"

# Schedule is referenced by the `attribute schedules` declaration below, so
# it must be loaded before the class body opens. The remaining playlist
# submodels (item, revision, checker) are loaded via `require "./playlist/*"`
# at the bottom of this file.
require "./playlist/schedule"

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

    attribute name : String, sanitize: :text, es_subfield: "keyword"
    attribute description : String = "", sanitize: :common

    belongs_to Authority, foreign_key: "authority_id"

    attribute orientation : Orientation = Orientation::Portrait, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::Playlist::Orientation)
    attribute play_count : Int64 = 0
    attribute play_through_count : Int64 = 0
    attribute default_animation : Animation = Animation::Cut, es_type: "integer", converter: Enum::ValueConverter(PlaceOS::Model::Playlist::Animation)

    attribute random : Bool = false
    attribute enabled : Bool = true

    # If the playlist is used to manage individually scheduled items
    # then it should be flagged as a distribution playlist
    # each item will have its own schedule (via item_schedule table)
    attribute distribution : Bool = false

    # time in milliseconds
    attribute default_duration : Int32 = 10_000

    # conditions that can determine when a playlist is valid
    attribute valid_from : Int64? = nil
    attribute valid_until : Int64? = nil

    # when this playlist should play — at least one schedule is required unless a distribution,
    # and each schedule must validate. Stored as a JSONB array.
    attribute schedules : Array(Playlist::Schedule) = -> { [Playlist::Schedule.new] },
      converter: PlaceOS::Model::DBArrConverter(PlaceOS::Model::Playlist::Schedule),
      es_ignore: true

    def should_present?(now : Time = Time.utc) : Bool
      return false unless enabled

      now_unix = now.to_unix
      starting = valid_from
      ending = valid_until
      return false if starting && starting > now_unix
      return false if ending && ending <= now_unix

      true
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

    # distribution playlists schedule each item individually, so the
    # playlist-level schedules don't apply. Everything else requires at least
    # one schedule, and each schedule must be individually valid.
    validate ->(this : Playlist) {
      return if this.distribution

      if this.schedules.empty?
        this.validation_error(:schedules, "is required")
        return
      end

      this.schedules.each_with_index do |schedule, index|
        if message = schedule.validation_message
          this.validation_error(:schedules, "schedule #{index + 1}: #{message}")
        end
      end
    }

    # the distribution flag determines how items are interpreted, so it must be
    # fixed at creation time to avoid orphaning existing item references.
    validate ->(this : Playlist) {
      if this.persisted? && this.distribution_changed?
        this.validation_error(:distribution, "cannot be changed after creation")
      end
    }
  end
end

require "./playlist/*"
