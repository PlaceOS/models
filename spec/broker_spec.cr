require "./helper"

module PlaceOS::Model
  describe Broker do
    test_round_trip(Broker)

    it "saves a Broker" do
      broker = Generator.broker.save!

      broker.should_not be_nil
      broker.persisted?.should be_true
      Broker.find!(broker.id.as(String)).id.should eq broker.id
    end
  end
end
