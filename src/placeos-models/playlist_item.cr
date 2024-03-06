require "./base/model"
require "./playlist"
require "./upload"

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

    # times in milliseconds (start time is for videos)
    attribute start_time : Int32 = 0
    attribute play_time : Int32 = 0
    attribute animation : Animation? = nil

    # media details
    attribute media_type : MediaType = MediaType::Image
    attribute orientation : Orientation = Orientation::Portrait

    # URI required for media hosted externally
    attribute media_uri : String? = nil
    belongs_to Upload, foreign_key: "media_id"
    belongs_to Upload, foreign_key: "thumbnail_id"

    # other metadata
    attribute play_count : Int64 = 0
    attribute valid_from : Time? = nil, converter: Time::EpochConverter
    attribute valid_until : Time? = nil, converter: Time::EpochConverter
  end
end
