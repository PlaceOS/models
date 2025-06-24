require "./helper"

module PlaceOS::Model
  Spec.before_each do
    Client.clear
  end

  describe Client do
    test_round_trip(Client)

    it "saves a Client" do
      client = Generator.client.save!

      client.should_not be_nil
      client.persisted?.should be_true
      Client.find!(client.id).id.should eq client.id
    end

    it "allow sub-clients" do
      parent = Generator.client.save!
      child = Generator.client(parent).save!
      child.parent_id.should eq parent.id
      client = Client.find!(parent.id)
      client.id.should eq parent.id
      client.children.should_not be_nil
      client.children.size.should eq(1)
      client.children.try &.first.id.should eq child.id
      puts client.to_pretty_json
    end
  end
end
