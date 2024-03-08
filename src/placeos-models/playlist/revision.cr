require "../base/model"
require "./item"

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
      Playlist::Item.where(id: items)
    end

    def clone : Playlist::Revision
      rev = Playlist::Revision.new
      rev.items = self.items
      rev.playlist_id = playlist_id
      rev
    end

    def user=(user)
      self.user_id = user.id.as(String)
      self.user_email = user.email
      self.user_name = user.name
    end

    def self.revisions(playlist_ids : Array(String))
      query = %[(playlist_id, created_at) IN (
        SELECT playlist_id, MAX(created_at) AS most_recent
        FROM playlist_revisions
        WHERE playlist_id = ANY(#{Associations.format_list_for_postgres(playlist_ids)})
        GROUP BY playlist_id
      )]
      Playlist::Revision.where(query).to_a
    end

    # Cleanup and items that don't exist
    ###############################################################################################
    before_save :check_items

    def check_items
      sql_query = %[
        WITH input_ids AS (
          SELECT unnest(#{Associations.format_list_for_postgres(self.items)}) AS id
        )

        SELECT ARRAY_AGG(input_ids.id)
        FROM input_ids
        LEFT JOIN playlist_items ON input_ids.id = playlist_items.id
        WHERE playlist_items.id IS NULL;
      ]

      remove_ids = PgORM::Database.connection do |conn|
        conn.query_one(sql_query, &.read(Array(String)?))
      end

      if remove_ids && !remove_ids.empty?
        self.items = self.items - remove_ids
      end
    end

    # Validation
    ###############################################################################################

    validates :playlist_id, presence: true
    validates :user_id, presence: true
    validates :user_name, presence: true
  end
end
