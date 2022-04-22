require "./helper"

module PlaceOS::Model
  describe Trigger do
    test_round_trip(Trigger)

    it "saves a trigger" do
      inst = Generator.trigger.save!
      Trigger.find!(inst.id.as(String)).id.should eq inst.id
    end

    it "validates webhook methods" do
      invalid_model = Generator.trigger
      invalid_model.supported_methods = ["NUGGET", "GET"]
      valid_model = Generator.trigger
      valid_model.supported_methods = ["POST", "GET"]

      valid_model.valid?.should be_true
      invalid_model.valid?.should be_false
      invalid_model.errors.size.should eq 1
      invalid_model.errors.first.to_s.should end_with "supported_methods contains invalid methods: NUGGET"
    end

    describe Trigger::Actions do
      it "validates function action" do
        model = Generator.trigger

        valid = Trigger::Actions::Function.new(
          mod: "anthropocene",
          method: "start"
        )
        invalid = Trigger::Actions::Function.new(
          mod: "anthropocene",
        )
        model.actions.try &.functions = [valid, invalid]

        model.valid?.should be_false
        model.errors.first.to_s.should end_with "method should not be nil"
      end

      it "validates email action" do
        model = Generator.trigger

        valid = Trigger::Actions::Email.new(
          emails: [Faker::Internet.email],
          content: "Hi"
        )
        invalid = Trigger::Actions::Email.new(
          content: "No email, whodis"
        )
        model.actions.try &.mailers = [valid, invalid]

        model.valid?.should be_false
        model.errors.size.should eq 1
        model.errors.first.to_s.should end_with "emails is required"
      end
    end

    describe Trigger::Conditions do
      it "validates time dependent condition" do
        model = Generator.trigger

        valid = Trigger::Conditions::TimeDependent.new(
          type: Trigger::Conditions::TimeDependent::Type::At,
          time: Time.utc,
        )

        invalid = Trigger::Conditions::TimeDependent.new(
          cron: "5 * * * *",
        )
        model.conditions.try &.time_dependents = [valid, invalid]

        model.valid?.should be_false
        model.errors.size.should eq 1
        model.errors.first.to_s.should end_with "type should not be nil"
      end

      it "validates comparison condition" do
        expect_raises(JSON::SerializableError) do
          Trigger::Conditions::Comparison.from_json({
            left:     false,
            operator: "asldkgjbn",
            right:    {
              mod:    "anthropocene",
              status: "{on: true}",
              keys:   ["on"],
            },
          }.to_json)
        end
      end
    end
  end
end
