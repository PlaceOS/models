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

    # other metadata
    attribute play_count : Int64 = 0
    attribute valid_from : Time? = nil, converter: Time::EpochConverter
    attribute valid_until : Time? = nil, converter: Time::EpochConverter

    def self.items(item_ids : Array(String)) : Array(Playlist::Item)
      Playlist::Item.where(id: item_ids).to_a
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
