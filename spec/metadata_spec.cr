require "./helper"

module PlaceOS::Model
  describe Metadata do
    it "saves control_system metadata" do
      control_system = Generator.control_system.save!
      meta = Generator.metadata(name: "test", parent: control_system.id.as(String)).save!

      control_system.metadata.first.id.should eq meta.id
      meta_find = Metadata.find!(meta.id.as(String))
      meta_find.control_system!.id.should eq control_system.id

      control_system.destroy
    end

    it "`modifying_user_id` is `nil` if modifying user is not recorded" do
      modifier = Generator.user.save!
      control_system = Generator.control_system.save!
      model = Metadata.new(name: "test")
      model.details = JSON::Any.new({} of String => JSON::Any)
      model.control_system = control_system
      model.modified_by = modifier
      model.save
      model.modified_by_id.should eq(modifier.id)
      model.details_will_change!
      model.save
      model.modified_by_id.should be_nil
    end

    it "saves zone metadata" do
      zone = Generator.zone.save!
      meta = Generator.metadata(parent: zone.id.as(String)).save!

      zone.metadata.first.id.should eq meta.id
      meta_find = Metadata.find!(meta.id.as(String))
      meta_find.zone!.id.should eq zone.id

      zone.destroy
    end

    it "serializes details field to string" do
      object = %({"hello":"world"})
      meta = Metadata.new(
        name: "hello",
        description: "",
        details: JSON.parse(object),
        parent_id: "1234",
        editors: Set(String).new,
      )

      # Serializes details to a string
      JSON.parse(meta.to_json)["details"].should eq %({"hello":"world"})

      # Satisfies round trip property
      Metadata.from_json(meta.to_json).details.should eq JSON.parse(object)
    end

    describe "for" do
      it "fetches metadata for a parent" do
        parent = Generator.zone.save!
        parent_id = parent.id.as(String)
        5.times do
          Generator.metadata(parent: parent_id).save!
        end
        Metadata.for(parent_id).to_a.size.should eq 5
        parent.destroy
      end
    end

    describe "build_metadata" do
      it "builds a response of metadata for a parent" do
        parent = Generator.zone.save!
        parent_id = parent.id.as(String)
        5.times do
          Generator.metadata(parent: parent_id).save!
        end
        Metadata.build_metadata(parent_id).size.should eq 5
        parent.destroy
      end
    end
  end
end
