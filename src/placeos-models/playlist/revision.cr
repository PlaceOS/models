require "../base/model"
require "./item"

module PlaceOS::Model
  class Playlist::Revision < ModelBase
    include PlaceOS::Model::Timestamps

    table :playlist_revisions

    attribute user_id : String?, mass_assignment: false
    attribute user_email : PlaceOS::Model::Email, format: "email", converter: PlaceOS::Model::EmailConverter, mass_assignment: false
    attribute user_name : String, mass_assignment: false

    attribute approved : Bool = false, mass_assignment: false
    attribute approved_by_id : String?, mass_assignment: false
    attribute approved_by_name : String?, mass_assignment: false
    attribute approved_by_email : PlaceOS::Model::Email?, format: "email", converter: PlaceOS::Model::EmailConverter, mass_assignment: false

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
      self.user_name = user.name
      self.user_email = user.email
    end

    def approver=(user)
      self.approved_by_id = user.id.as(String)
      self.approved_by_name = user.name
      self.approved_by_email = user.email
      self.approved = true
    end

    # finds the latest approved playlist revision for each of the playlist ids provided
    def self.revisions(playlist_ids : Array(String), approved : Bool? = true)
      query = %[(playlist_id, created_at) IN (
        SELECT playlist_id, MAX(created_at) AS most_recent
        FROM playlist_revisions
        WHERE playlist_id = ANY(#{Associations.format_list_for_postgres(playlist_ids)})
        GROUP BY playlist_id
      )]
      results = Playlist::Revision.where(query)

      case approved
      in Bool
        results.where(approved: approved).to_a
      in Nil
        results.to_a
      end
    end

    # Cleanup and items that don't exist
    ###############################################################################################
    before_create :remove_old_draft_revisions

    def remove_old_draft_revisions
      if !self.approved
        Playlist::Revision.where(approved: false, playlist_id: self.playlist_id).delete_all
      end
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

      remove_ids = ::PgORM::Database.connection do |conn|
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
