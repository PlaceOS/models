require "./support/tenancy_migrations"

module PlaceOS::Model
  def self.legacy_duplicate_authorities : {Authority, Authority}
    PgORM::Database.connection(&.exec("DROP INDEX IF EXISTS authority_domain_unique"))
    first = Generator.authority("legacy-#{RANDOM.hex(5)}.test").save!
    duplicate_id = "auth-legacy-duplicate-#{RANDOM.hex(6)}"
    PgORM::Database.connection do |db|
      columns = db.query_all(<<-SQL, as: String)
        SELECT column_name FROM information_schema.columns
        WHERE table_schema = current_schema() AND table_name = 'authority' AND is_generated = 'NEVER'
        ORDER BY ordinal_position
        SQL
      fields = columns.map { |column| %Q("#{column}") }.join(", ")
      values = columns.map do |column|
        case column
        when "id"         then "$2::text"
        when "created_at" then %(a."created_at" + interval '1 second')
        else                   %(a."#{column}")
        end
      end.join(", ")
      db.exec("INSERT INTO authority (#{fields}) SELECT #{values} FROM authority a WHERE a.id = $1", args: [first.id, duplicate_id])
    end
    {first, Authority.find!(duplicate_id)}
  end

  describe "authority domain upgrade safety" do
    around_each do |example|
      PgORM::Database.transaction do |transaction|
        example.run
      ensure
        transaction.rollback unless transaction.closed?
      end
    end

    it "preserves duplicate legacy domains instead of renaming them or blocking migration" do
      first, second = legacy_duplicate_authorities

      apply_organisation_migration("20261105100500000_add_partners_and_organisations.sql")

      Authority.find!(first.id.as(String)).domain.should eq first.domain
      Authority.find!(second.id.as(String)).domain.should eq first.domain
      PgORM::Database.connection do |db|
        db.query_one("SELECT to_regclass('authority_domain_unique') IS NULL", &.read(Bool)).should be_true
      end
    end

    it "adds the unique domain index when the existing domains are unambiguous" do
      PgORM::Database.connection(&.exec("DROP INDEX IF EXISTS authority_domain_unique"))

      apply_organisation_migration("20261105100500000_add_partners_and_organisations.sql")

      PgORM::Database.connection do |db|
        db.query_one("SELECT to_regclass('authority_domain_unique') IS NOT NULL", &.read(Bool)).should be_true
      end
    end

    it "reports both duplicate authorities for explicit operator reconciliation" do
      first, second = legacy_duplicate_authorities

      PgORM::Database.connection do |db|
        count = db.query_one(<<-SQL, args: [first.id, second.id], &.read(Int64))
          SELECT COUNT(*) FROM tenancy_ownership_conflicts
          WHERE resource_type = 'authority' AND reason = 'duplicate_domain' AND resource_id IN ($1, $2)
          SQL
        count.should eq 2
      end
    end

    it "does not infer organisation ownership for duplicate domains" do
      first, second = legacy_duplicate_authorities

      apply_organisation_migration

      Authority.find!(first.id.as(String)).organisation_id.should be_nil
      Authority.find!(second.id.as(String)).organisation_id.should be_nil
    end

    it "reports domains quarantined by an already applied older migration" do
      authority = Generator.authority("legacy-#{RANDOM.hex(5)}.test").save!
      authority.domain = "#{authority.domain}.duplicate.#{authority.id}"
      authority.save!

      PgORM::Database.connection do |db|
        count = db.query_one(<<-SQL, args: [authority.id], &.read(Int64))
          SELECT COUNT(*) FROM tenancy_ownership_conflicts
          WHERE resource_type = 'authority' AND resource_id = $1 AND reason = 'quarantined_domain'
          SQL
        count.should eq 1
      end
      Authority.find!(authority.id.as(String)).domain.should eq authority.domain
    end

    it "creates the missing domain index after explicit duplicate resolution on an applied install" do
      first, second = legacy_duplicate_authorities
      PgORM::Database.connection(&.exec("UPDATE authority SET domain = $1 WHERE id = $2", args: ["resolved-#{RANDOM.hex(5)}.test", second.id]))
      migration = "20261117100700000_guard_authority_domains.sql"
      File.exists?(File.join(__DIR__, "..", "migration", "db", "migrations", migration)).should be_true

      apply_organisation_migration(migration)

      PgORM::Database.connection do |db|
        db.query_one("SELECT to_regclass('authority_domain_unique') IS NOT NULL", &.read(Bool)).should be_true
      end
      Authority.find!(first.id.as(String)).domain.should eq first.domain
    end
  end
end
