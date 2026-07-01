require "../base/model"
require "../playlist"
require "./item"

# Schedule is referenced by the `attribute schedules` declaration below.
require "./schedule"

module PlaceOS::Model
  # Wraps a single Playlist::Item with its own set of schedules. Used by
  # "distribution" playlists, where each media item is scheduled individually
  # rather than the whole playlist sharing one schedule. Owned 1:1 by the
  # distribution playlist (removed via ON DELETE CASCADE when either the
  # playlist or the underlying item is deleted).
  class Playlist::ItemSchedule < ModelBase
    include PlaceOS::Model::Timestamps

    table :playlist_item_schedules

    belongs_to Playlist, foreign_key: "playlist_id"
    belongs_to Playlist::Item, foreign_key: "item_id", association_name: "item"

    # when this item should play — at least one schedule is required, and each
    # schedule must validate. Stored as a JSONB array. Not indexed in elastic.
    attribute schedules : Array(Playlist::Schedule) = -> { [Playlist::Schedule.new] },
      converter: PlaceOS::Model::DBArrConverter(PlaceOS::Model::Playlist::Schedule),
      es_ignore: true

    # Validation
    ###############################################################################################

    validates :playlist_id, presence: true
    validates :item_id, presence: true
    # presence on an array attribute ⇒ at least one element
    validates :schedules, presence: true

    # each schedule must be individually valid
    validate ->(this : Playlist::ItemSchedule) {
      this.schedules.each_with_index do |schedule, index|
        if message = schedule.validation_message
          this.validation_error(:schedules, "schedule #{index + 1}: #{message}")
        end
      end
    }

    # the scheduled item and its playlist must belong to the same authority
    validate ->(this : Playlist::ItemSchedule) {
      playlist = this.playlist
      item = this.item
      return unless playlist && item

      if playlist.authority_id != item.authority_id
        this.validation_error(:item_id, "must belong to the same authority as the playlist")
      end
    }

    # Cleanup — strip this schedule's id from any playlist revisions referencing it
    ###############################################################################################
    before_destroy :cleanup_playlists

    protected def cleanup_playlists
      schedule_id = self.id.as(String)

      # grab all the playlists that reference this schedule so we can bump their
      # updated_at (cache invalidation) after removing the reference
      playlist_ids = ::PgORM::Database.connection do |conn|
        conn.query_one(%[
          SELECT array_agg(DISTINCT playlist_id) AS playlist_ids
          FROM playlist_revisions
          WHERE '#{schedule_id}' = ANY(items)
        ], &.read(Array(String)?))
      end

      ::PgORM::Database.exec_sql(%[
        UPDATE playlist_revisions
        SET items = array_remove(items, '#{schedule_id}')
        WHERE '#{schedule_id}' = ANY(items)
      ])

      return unless playlist_ids
      return if playlist_ids.empty?

      ::PgORM::Database.exec_sql(%[
        UPDATE playlists
        SET updated_at = CURRENT_TIMESTAMP
        WHERE id IN ('#{playlist_ids.join("', '")}')
      ])
    end
  end
end
