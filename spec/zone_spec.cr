require "./helper"

module PlaceOS::Model
  describe Zone do
    test_round_trip(Zone)

    it "saves a zone" do
      zone = Generator.zone

      begin
        zone.save!
      rescue e : RethinkORM::Error::DocumentInvalid
        inspect_error(e)
        raise e
      end

      zone.should_not be_nil
      id = zone.id
      id.should start_with "zone-" if id
      zone.persisted?.should be_true
    end

    it "no duplicate zone names" do
      expect_raises(RethinkORM::Error::DocumentInvalid) do
        name = RANDOM.base64(10)
        zone1 = Zone.new(
          name: name,
        )
        zone1.save!
        zone2 = Zone.new(
          name: name,
        )
        zone2.save!
      end
    end

    it "has unique tags" do
      zone = Generator.zone
      zone.tags << "hello"
      zone.tags << "hello"
      zone.tags << "bye"
      zone.save!
      Zone.find!(zone.id.as(String)).tags.should eq Set{"hello", "bye"}
    end

    it "supports zone hierarchies" do
      zone = Generator.zone

      begin
        zone.save!
      rescue e : RethinkORM::Error::DocumentInvalid
        inspect_error(e)
        raise e
      end

      zone.should_not be_nil
      id = zone.id.as(String)
      id.should start_with "zone-"
      zone.persisted?.should be_true

      zone2 = Generator.zone
      zone2.parent_id = id
      begin
        zone2.save!
      rescue e : RethinkORM::Error::DocumentInvalid
        inspect_error(e)
        raise e
      end

      id2 = zone2.id.as(String)
      id2.should start_with "zone-"

      zone.children.to_a.map(&.id).should eq [id2]
      zone2.parent!.id.should eq id

      # show that deleting the parent deletes the children
      Zone.find!(id2.as(String)).id.should eq id2
      zone.destroy
      Zone.find(id2.as(String)).should be_nil
    end

    it "should create triggers when added and removed from a zone" do
      # Set up
      zone = Generator.zone.save!
      cs = Generator.control_system

      id = zone.id
      cs.zones = [id] if id

      cs.save!

      trigger = Trigger.create!(name: "trigger test", authority_id: "spec-authority-id")

      # No trigger_instances associated with zone
      zone.trigger_instances.to_a.size.should eq 0
      cs.triggers.to_a.size.should eq 0

      id = trigger.id
      zone.triggers = [id] if id
      zone.triggers_changed?.should be_true
      zone.save

      trigs = cs.triggers.to_a
      trigs.size.should eq 1
      trigs.first.zone_id.should eq zone.id

      # Reload the relationships
      zone = Zone.find!(zone.id.as(String))

      zone.trigger_instances.to_a.size.should eq 1
      zone.triggers = [] of String
      zone.save

      zone = Zone.find!(zone.id.as(String))
      zone.trigger_instances.to_a.size.should eq 0

      {cs, zone, trigger}.each &.destroy
    end

    describe "queries" do
      it ".with_tag" do
        zones = (0..5).map do |n|
          zone = Generator.zone
          zone.tags = (0..n).map(&.to_s).to_set
          zone.save!
        end

        Zone.with_tag("0", "spec-authority-id").to_a.compact_map(&.id).sort!.should eq zones.compact_map(&.id).sort!
        Zone.with_tag("3", "spec-authority-id").to_a.compact_map(&.id).sort!.should eq zones[3..].compact_map(&.id).sort!

        zones.each &.destroy
      end
    end

    describe "validations" do
      it "ensure associated authority" do
        zone = Generator.zone
        zone.authority_id = ""
        zone.valid?.should be_false
        zone.errors.first.field.should eq :authority_id
      end
    end
  end
end
