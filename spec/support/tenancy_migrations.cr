require "../helper"

module PlaceOS::Model
  # Execute the shipped migration, rather than a copy of its ownership queries.
  def self.apply_organisation_migration(filename : String = "20261105100600000_backfill_organisation_ownership.sql")
    path = File.join(__DIR__, "..", "..", "migration", "db", "migrations", filename)
    sql = File.read(path).split("-- +micrate Down", 2).first
    statement = String::Builder.new
    block = false
    sql.each_line do |line|
      if line.includes?("-- +micrate StatementBegin")
        block = true
      elsif line.includes?("-- +micrate StatementEnd")
        PgORM::Database.connection(&.exec(statement.to_s))
        statement = String::Builder.new
        block = false
      else
        statement << line << '\n'
        if !block && line.rstrip.ends_with?(';')
          PgORM::Database.connection(&.exec(statement.to_s))
          statement = String::Builder.new
        end
      end
    end
  end
end
