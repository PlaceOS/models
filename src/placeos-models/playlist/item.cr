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

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""

    belongs_to Authority, foreign_key: "authority_id"

    # times in milliseconds (start time is for videos)
    attribute video_length : Int32? = nil
    attribute start_time : Int32 = 0
    attribute play_time : Int32 = 0
    attribute animation : Animation? = nil, es_type: "integer", converter: Enum::ValueConverter(PlaceOS::Model::Playlist::Animation)

    # media details
    attribute media_type : MediaType = MediaType::Image, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::Playlist::Item::MediaType)
    attribute orientation : Orientation = Orientation::Portrait, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::Playlist::Orientation)

    # URI required for media hosted externally
    attribute media_uri : String? = nil
    belongs_to Upload, foreign_key: "media_id", association_name: "media"
    belongs_to Upload, foreign_key: "thumbnail_id", association_name: "thumbnail"

    attribute media_details : Upload? = nil, persistence: false, show: true, description: "details of the media_id specified"
    attribute thumbnail_details : Upload? = nil, persistence: false, show: true, description: "details of the thumbnail_id specified"

    # other metadata
    attribute play_count : Int64 = 0
    attribute valid_from : Time? = nil, converter: Time::EpochConverter
    attribute valid_until : Time? = nil, converter: Time::EpochConverter

    def self.items(item_ids : Array(String)) : Array(Playlist::Item)
      Playlist::Item.where(id: item_ids).to_a
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
        begin
          raise "no media type" unless this.media
        rescue
          this.validation_error(:media_id, "must specify a media upload id")
        end
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
  end
end
