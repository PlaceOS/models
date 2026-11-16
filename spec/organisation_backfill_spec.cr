require "./helper"

module PlaceOS::Model
  # Execute the shipped migration, rather than a copy of its ownership queries.
  def self.apply_organisation_backfill
    path = File.join(__DIR__, "..", "migration", "db", "migrations", "20261105100600000_backfill_organisation_ownership.sql")
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

  describe "organisation ownership migration" do
    around_each do |example|
      PgORM::Database.transaction do |transaction|
        example.run
      ensure
        transaction.rollback unless transaction.closed?
      end
    end

    it "quarantines a system with both owned and unknown zones" do
      organisation = Generator.organisation.save!
      owned = Generator.zone.tap(&.organisation_id = organisation.id).save!
      unknown = Generator.zone.save!
      system = Generator.control_system.tap(&.zones = [owned.id.as(String), unknown.id.as(String)]).save!

      apply_organisation_backfill

      ControlSystem.find!(system.id.as(String)).organisation_id.should be_nil
    end

    it "assigns a system whose zones all have the same known owner" do
      organisation = Generator.organisation.save!
      zones = Array.new(2) { Generator.zone.tap(&.organisation_id = organisation.id).save! }
      system = Generator.control_system.tap(&.zones = zones.map(&.id.as(String))).save!

      apply_organisation_backfill

      ControlSystem.find!(system.id.as(String)).organisation_id.should eq organisation.id
    end

    it "quarantines a system whose zone array includes a missing reference" do
      organisation = Generator.organisation.save!
      owned = Generator.zone.tap(&.organisation_id = organisation.id).save!
      system = Generator.control_system.tap(&.zones = [owned.id.as(String), "zone-missing-#{RANDOM.hex(5)}"]).save!

      apply_organisation_backfill

      ControlSystem.find!(system.id.as(String)).organisation_id.should be_nil
    end

    it "quarantines a shared module referenced by owned and unknown systems" do
      organisation = Generator.organisation.save!
      mod = Generator.module(driver: Generator.driver(role: Driver::Role::Device)).save!
      Generator.control_system.tap do |system|
        system.organisation_id = organisation.id
        system.modules = [mod.id.as(String)]
      end.save!
      Generator.control_system.tap(&.modules = [mod.id.as(String)]).save!

      apply_organisation_backfill

      Module.find!(mod.id.as(String)).organisation_id.should be_nil
    end

    it "assigns a shared module when every referencing system has the same owner" do
      organisation = Generator.organisation.save!
      mod = Generator.module(driver: Generator.driver(role: Driver::Role::Device)).save!
      2.times do
        Generator.control_system.tap do |system|
          system.organisation_id = organisation.id
          system.modules = [mod.id.as(String)]
        end.save!
      end

      apply_organisation_backfill

      Module.find!(mod.id.as(String)).organisation_id.should eq organisation.id
    end

    it "quarantines a logic module also referenced by an unknown system" do
      organisation = Generator.organisation.save!
      owned = Generator.control_system.tap(&.organisation_id = organisation.id).save!
      mod = Generator.module(driver: Generator.driver(role: Driver::Role::Logic), control_system: owned).save!
      Generator.control_system.tap(&.modules = [mod.id.as(String)]).save!

      apply_organisation_backfill

      Module.find!(mod.id.as(String)).organisation_id.should be_nil
    end

    it "quarantines a claimed zone tree containing a conflicting assigned owner" do
      organisation = Generator.organisation.save!
      other = Generator.organisation.save!
      root = Generator.zone.save!
      Generator.zone.tap do |zone|
        zone.parent_id = root.id
        zone.organisation_id = other.id
      end.save!
      unknown = Generator.zone.tap(&.parent_id = root.id).save!
      Generator.authority("backfill-#{RANDOM.hex(5)}.test").tap do |authority|
        authority.organisation_id = organisation.id
        authority.config["org_zone"] = JSON::Any.new(root.id.as(String))
      end.save!

      apply_organisation_backfill

      Zone.find!(unknown.id.as(String)).organisation_id.should be_nil
      Zone.find!(root.id.as(String)).organisation_id.should be_nil
    end

    it "preserves already assigned ownership when legacy references are unresolved" do
      organisation = Generator.organisation.save!
      unknown = Generator.zone.save!
      system = Generator.control_system.tap do |row|
        row.organisation_id = organisation.id
        row.zones = [unknown.id.as(String)]
      end.save!

      apply_organisation_backfill

      ControlSystem.find!(system.id.as(String)).organisation_id.should eq organisation.id
    end
  end
end
