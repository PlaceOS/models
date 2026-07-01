require "../base/model"
require "../playlist"
require "../upload"
require "uri"

module PlaceOS::Model
  class Playlist::Item < ModelBase
    include PlaceOS::Model::Timestamps

    table :playlist_items

    enum MediaType
      Image
      Video
      Plugin
      Webpage
      ExternalImage
    end

    attribute name : String, sanitize: :text, es_subfield: "keyword"
    attribute description : String = "", sanitize: :common
    attribute tags : Set(String) = -> { Set(String).new }, sanitize: :text

    belongs_to Authority, foreign_key: "authority_id"

    # times in milliseconds (start time is for videos)
    attribute video_length : Int32? = nil
    attribute start_time : Int32 = 0
    attribute play_time : Int32 = 0
    attribute animation : Animation = Animation::Default, es_type: "integer", converter: Enum::ValueConverter(PlaceOS::Model::Playlist::Animation)

    # media details
    attribute media_type : MediaType = MediaType::Image, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::Playlist::Item::MediaType)
    attribute orientation : Orientation = Orientation::Portrait, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::Playlist::Orientation)

    # URI required for media hosted externally
    attribute media_uri : String? = nil
    belongs_to Upload, foreign_key: "media_id", association_name: "media"
    belongs_to Upload, foreign_key: "thumbnail_id", association_name: "thumbnail"

    # plugin data for playback
    belongs_to SignagePlugin, foreign_key: "plugin_id", association_name: "plugin"
    attribute plugin_params : Hash(String, JSON::Any) = {} of String => JSON::Any

    # other metadata
    attribute play_count : Int64 = 0
    attribute valid_from : Int64? = nil
    attribute valid_until : Int64? = nil

    def self.items(item_ids : Array(String)) : Array(Playlist::Item)
      Playlist::Item.where(id: item_ids).to_a
    end

    def self.with_tag(tag : String)
      Playlist::Item.where("$1 = Any(tags)", tag)
    end

    def self.update_counts(metrics : Hash(String, Int32)) : Int64
      return 0_i64 if metrics.empty?

      metrics = metrics.transform_keys(&.gsub("'", "''"))

      update_item_counts = String.build do |str|
        str << %[
          UPDATE playlist_items
          SET play_count = play_count + CASE id
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

    # Validation
    ###############################################################################################

    validates :name, presence: true

    # ensure media is configured correctly
    validate ->(this : Playlist::Item) {
      case this.media_type
      when .image?, .video?
        this.validation_error(:media_id, "must specify a media upload id") unless this.media
      when .plugin?
        this.validate_plugin
      else
        if media_uri = this.media_uri.presence
          begin
            uri = URI.parse(media_uri)
            raise "invalid scheme" unless {"http", "https"}.includes?(uri.scheme.try(&.downcase))
            raise "requires a host" unless uri.host.presence
            raise "requires a path" unless uri.path.presence
          rescue error
            this.validation_error(:media_uri, "not valid: #{error.message}")
          end
        else
          this.validation_error(:media_uri, "required for #{this.media_type}")
        end
      end
    }

    protected def validate_plugin
      plugin = self.plugin
      unless plugin
        self.validation_error(:plugin_id, "must specify a plugin id")
        return
      end

      params = self.plugin_params
      properties = plugin.params["properties"]?.try(&.as_h?)

      # ensure plugin_params keys exist in plugin params properties
      params.each_key do |key|
        unless properties.try(&.has_key?(key))
          self.validation_error(:plugin_params, "key '#{key}' does not exist in plugin params properties")
        end
      end

      # ensure all required params are satisfied by defaults merged with plugin_params
      if required = plugin.params["required"]?.try(&.as_a?)
        merged = plugin.defaults.merge(params)
        required.each do |req_key|
          key = req_key.as_s?
          next unless key
          unless merged.has_key?(key)
            self.validation_error(:plugin_params, "missing required param '#{key}'")
          end
        end
      end
    end

    before_destroy :cleanup_playlists

    # Remove this item (and any distribution schedules wrapping it) from the
    # revisions that reference them, then bump the owning playlists' timestamps.
    protected def cleanup_playlists
      reference_ids = revision_reference_ids
      ref_array = Associations.format_list_for_postgres(reference_ids)

      # grab all the playlists that reference this item / its schedules
      playlist_ids = ::PgORM::Database.connection do |conn|
        conn.query_one(%[
          SELECT array_agg(DISTINCT playlist_id) AS playlist_ids
          FROM playlist_revisions
          WHERE items && #{ref_array}
        ], &.read(Array(String)?))
      end

      # remove the references from playlist revisions, preserving item order
      ::PgORM::Database.exec_sql(%[
        UPDATE playlist_revisions
        SET items = COALESCE((
          SELECT array_agg(elem ORDER BY ord)
          FROM unnest(items) WITH ORDINALITY AS t(elem, ord)
          WHERE elem <> ALL(#{ref_array})
        ), '{}'::text[])
        WHERE items && #{ref_array}
      ])

      bump_playlist_timestamps(playlist_ids)
    end

    after_update :update_playlists

    def update_playlists
      ref_array = Associations.format_list_for_postgres(revision_reference_ids)

      # grab all the playlists that reference this item / its schedules
      playlist_ids = ::PgORM::Database.connection do |conn|
        conn.query_one(%[
          SELECT array_agg(DISTINCT playlist_id) AS playlist_ids
          FROM playlist_revisions
          WHERE items && #{ref_array}
        ], &.read(Array(String)?))
      end

      bump_playlist_timestamps(playlist_ids)
    end

    # ids referenced by playlist revisions for this item: the item itself
    # (scheduling playlists) plus any item_schedules wrapping it (distribution
    # playlists reference the schedule id, not the item id)
    protected def revision_reference_ids : Array(String)
      item_id = self.id.as(String)

      schedule_ids = ::PgORM::Database.connection do |conn|
        conn.query_one(%[
          SELECT array_agg(id)
          FROM playlist_item_schedules
          WHERE item_id = '#{item_id}'
        ], &.read(Array(String)?))
      end

      ids = [item_id]
      ids.concat(schedule_ids) if schedule_ids
      ids
    end

    protected def bump_playlist_timestamps(playlist_ids : Array(String)?)
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
