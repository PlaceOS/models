module PlaceOS::Model::Playlist::Checker
  macro included
    before_save :check_playlists
  end

  def check_playlists
    sql_query = %[
      WITH input_ids AS (
        SELECT unnest(#{Associations.format_list_for_postgres(self.playlists)}) AS id
      )

      SELECT ARRAY_AGG(input_ids.id)
      FROM input_ids
      LEFT JOIN playlists ON input_ids.id = playlists.id
      WHERE playlists.id IS NULL;
    ]

    remove_ids = ::PgORM::Database.connection do |conn|
      conn.query_one(sql_query, &.read(Array(String)?))
    end

    if remove_ids && !remove_ids.empty?
      self.playlists = self.playlists - remove_ids
    end
  end
end
