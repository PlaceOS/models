require "./helper"

module PlaceOS::Model
  describe "organisation name uniqueness rollout" do
    around_each do |example|
      previous = ENV["PLACE_TENANCY_ENFORCE"]?
      ENV["PLACE_TENANCY_ENFORCE"] = "false"
      PgORM::Database.transaction do |transaction|
        example.run
      ensure
        transaction.rollback unless transaction.closed?
      end
    ensure
      if previous
        ENV["PLACE_TENANCY_ENFORCE"] = previous
      else
        ENV.delete("PLACE_TENANCY_ENFORCE")
      end
    end

    {% for type in [Zone, ControlSystem, Edge, Broker] %}
      it "keeps {{type.id}} names globally unique while tenancy is disabled" do
        first_org = Generator.organisation.save!
        second_org = Generator.organisation.save!
        name = "legacy-name-#{RANDOM.hex(6)}"
        first = Generator.{{type.stringify.split("::").last.underscore.id}}
        first.name = name
        first.organisation_id = first_org.id
        first.save!
        duplicate = Generator.{{type.stringify.split("::").last.underscore.id}}
        duplicate.name = name
        duplicate.organisation_id = second_org.id

        duplicate.valid?.should be_false
        duplicate.errors.map(&.field).should contain(:name)
      end

      it "keeps unowned {{type.id}} names from duplicating an owned legacy name" do
        organisation = Generator.organisation.save!
        name = "legacy-name-#{RANDOM.hex(6)}"
        first = Generator.{{type.stringify.split("::").last.underscore.id}}
        first.name = name
        first.organisation_id = organisation.id
        first.save!
        duplicate = Generator.{{type.stringify.split("::").last.underscore.id}}
        duplicate.name = name

        duplicate.valid?.should be_false
      end
    {% end %}
  end
end
