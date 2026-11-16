require "./helper"

module PlaceOS::Model
  describe "tenancy ownership reconciliation report" do
    around_each do |example|
      PgORM::Database.transaction do |transaction|
        example.run
      ensure
        transaction.rollback unless transaction.closed?
      end
    end

    it "reports an already assigned system's unknown references without changing its owner" do
      organisation = Generator.organisation.save!
      unknown = Generator.zone.save!
      system = Generator.control_system.tap do |row|
        row.organisation_id = organisation.id
        row.zones = [unknown.id.as(String)]
      end.save!

      PgORM::Database.connection do |db|
        db.query_one("SELECT to_regclass('tenancy_ownership_conflicts') IS NOT NULL", &.read(Bool)).should be_true
        count = db.query_one(<<-SQL, system.id, unknown.id, &.read(Int64))
          SELECT COUNT(*) FROM tenancy_ownership_conflicts
          WHERE resource_type = 'sys' AND resource_id = $1 AND reason = 'unknown_reference'
            AND related_type = 'zone' AND related_id = $2
          SQL
        count.should eq 1
      end
      ControlSystem.find!(system.id.as(String)).organisation_id.should eq organisation.id
    end

    it "reports a conflicting assigned zone parent without silently reassigning either row" do
      organisation = Generator.organisation.save!
      other = Generator.organisation.save!
      parent = Generator.zone.tap(&.organisation_id = organisation.id).save!
      child = Generator.zone.tap do |row|
        row.parent_id = parent.id
        row.organisation_id = other.id
      end.save!

      PgORM::Database.connection do |db|
        db.query_one("SELECT to_regclass('tenancy_ownership_conflicts') IS NOT NULL", &.read(Bool)).should be_true
        count = db.query_one(<<-SQL, child.id, parent.id, &.read(Int64))
          SELECT COUNT(*) FROM tenancy_ownership_conflicts
          WHERE resource_type = 'zone' AND resource_id = $1 AND reason = 'ownership_mismatch'
            AND related_type = 'zone' AND related_id = $2
          SQL
        count.should eq 1
      end
      Zone.find!(child.id.as(String)).organisation_id.should eq other.id
      Zone.find!(parent.id.as(String)).organisation_id.should eq organisation.id
    end
  end
end
