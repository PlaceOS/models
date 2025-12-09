require "./helper"

module PlaceOS::Model
  describe History do
    Spec.before_each do
      History.clear
    end

    test_round_trip(History)

    it "saves a History" do
      history = Generator.history.save!

      history.should_not be_nil
      history.persisted?.should be_true
      history.id.as(String).starts_with?("history-").should be_true

      found = History.find!(history.id.as(String))
      found.id.should eq history.id
      found.type.should eq history.type
      found.object_id.should eq history.object_id
      found.changed_fields.should eq history.changed_fields
    end

    it "requires type" do
      history = History.new(
        type: "",
        object_id: "zone-123"
      )
      history.valid?.should be_false
      history.errors.first.field.should eq :type
    end

    it "requires object_id" do
      history = History.new(
        type: "zone",
        object_id: ""
      )
      history.valid?.should be_false
      history.errors.first.field.should eq :object_id
    end

    it "defaults changed_fields to empty array" do
      history = History.new(
        type: "zone",
        object_id: "zone-123"
      )
      history.save!

      history.changed_fields.should eq [] of String
    end

    it "sets timestamps on create" do
      history = Generator.history.save!

      history.created_at.should_not be_nil
      history.updated_at.should_not be_nil
    end
  end
end
