require "./support/tenancy_migrations"

module PlaceOS::Model
  def self.module_edge_fixture(edge_owner : Organisation?)
    organisation = Generator.organisation.save!
    authority = Generator.authority("edge-owner-#{RANDOM.hex(5)}.test")
    authority.organisation_id = edge_owner.try(&.id) || organisation.id
    authority.save!
    user = Generator.user(authority: authority).save!
    edge = Generator.edge(user: user)
    edge.organisation_id = edge_owner.try(&.id)
    edge.save!
    mod = Generator.module(driver: Generator.driver(role: Driver::Role::Device))
    mod.edge_id = edge.id
    mod.save!
    system = Generator.control_system.tap do |row|
      row.organisation_id = organisation.id
      row.modules = [mod.id.as(String)]
    end.save!
    {organisation, edge, mod, system}
  end

  describe "module edge ownership backfill" do
    around_each do |example|
      PgORM::Database.transaction do |transaction|
        example.run
      ensure
        transaction.rollback unless transaction.closed?
      end
    end

    it "quarantines an unowned module bound to another organisation's edge" do
      other = Generator.organisation.save!
      _, _, mod, _ = module_edge_fixture(other)

      apply_organisation_migration

      Module.find!(mod.id.as(String)).organisation_id.should be_nil
    end

    it "quarantines an unowned module whose configured edge does not exist" do
      _, _, mod, _ = module_edge_fixture(nil)
      PgORM::Database.connection(&.exec("UPDATE mod SET edge_id = $1 WHERE id = $2", args: ["edge-missing-#{RANDOM.hex(5)}", mod.id]))

      apply_organisation_migration

      Module.find!(mod.id.as(String)).organisation_id.should be_nil
    end

    it "quarantines an unowned module when its edge owner cannot be inferred" do
      _, edge, mod, _ = module_edge_fixture(nil)
      PgORM::Database.connection(&.exec("UPDATE edge SET user_id = $1 WHERE id = $2", args: ["user-missing-#{RANDOM.hex(5)}", edge.id]))

      apply_organisation_migration

      Edge.find!(edge.id.as(String)).organisation_id.should be_nil
      Module.find!(mod.id.as(String)).organisation_id.should be_nil
    end

    it "assigns a module when its system and actual edge have the same known owner" do
      organisation, edge, mod, _ = module_edge_fixture(nil)
      edge.organisation_id = organisation.id
      edge.save!

      apply_organisation_migration

      Module.find!(mod.id.as(String)).organisation_id.should eq organisation.id
    end

    it "preserves assigned ownership and reports a conflicting edge for reconciliation" do
      other = Generator.organisation.save!
      organisation, _, mod, _ = module_edge_fixture(other)
      mod.organisation_id = organisation.id
      mod.save!

      apply_organisation_migration

      Module.find!(mod.id.as(String)).organisation_id.should eq organisation.id
      PgORM::Database.connection do |db|
        count = db.query_one(<<-SQL, args: [mod.id], &.read(Int64))
          SELECT COUNT(*) FROM tenancy_ownership_conflicts
          WHERE resource_type = 'mod' AND resource_id = $1 AND related_type = 'edge' AND reason = 'ownership_mismatch'
          SQL
        count.should eq 1
      end
    end

    it "applies the conservative edge guard to NULL module ownership on an already migrated install" do
      other = Generator.organisation.save!
      _, _, mod, _ = module_edge_fixture(other)
      migration = "20261117100800000_guard_module_edge_ownership.sql"
      File.exists?(File.join(__DIR__, "..", "migration", "db", "migrations", migration)).should be_true

      apply_organisation_migration(migration)

      Module.find!(mod.id.as(String)).organisation_id.should be_nil
    end
  end
end
