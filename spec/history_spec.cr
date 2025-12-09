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
      found.resource_id.should eq history.resource_id
      found.action.should eq history.action
      found.changed_fields.should eq history.changed_fields
    end

    it "requires type" do
      history = History.new(
        type: "",
        resource_id: "zone-123",
        action: "update"
      )
      history.valid?.should be_false
      history.errors.first.field.should eq :type
    end

    it "requires resource_id" do
      history = History.new(
        type: "zone",
        resource_id: "",
        action: "update"
      )
      history.valid?.should be_false
      history.errors.first.field.should eq :resource_id
    end

    it "defaults changed_fields to empty array" do
      history = History.new(
        type: "zone",
        resource_id: "zone-123",
        action: "create"
      )
      history.save!

      history.changed_fields.should eq [] of String
    end

    it "saves action field" do
      history = History.new(
        type: "zone",
        resource_id: "zone-123",
        action: "update",
        changed_fields: ["name"]
      )
      history.save!

      found = History.find!(history.id.as(String))
      found.action.should eq "update"
    end

    it "supports different action types" do
      ["create", "update", "delete"].each do |action|
        history = History.new(
          type: "zone",
          resource_id: "zone-123",
          action: action
        )
        history.save!
        history.action.should eq action
      end
    end

    it "sets timestamps on create" do
      history = Generator.history.save!

      history.created_at.should_not be_nil
      history.updated_at.should_not be_nil
    end
  end
end
