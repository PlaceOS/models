require "./base/model"
require "./playlist_item"

module PlaceOS::Model
  class Playlist::Revision < ModelBase
    include PlaceOS::Model::Timestamps

    table :playlist_revisions

    attribute user_id : String
    attribute user_email : PlaceOS::Model::Email, format: "email", converter: PlaceOS::Model::EmailConverter
    attribute user_name : String

    attribute items : Array(String) = [] of String, es_type: "keyword"
    belongs_to Playlist, foreign_key: "playlist_id"

    def fetch_items
      Items.where(id: items)
    end
  end
end
