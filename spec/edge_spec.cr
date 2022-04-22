require "./helper"

module PlaceOS::Model
  describe Edge do
    test_round_trip(Edge)

    it "saves an Edge" do
      edge = Generator.edge.save!
      edge.should_not be_nil
      edge.persisted?.should be_true
      Edge.find!(edge.id.as(String)).id.should eq edge.id
    end

    it "generates a token for the edge" do
      edge = Generator.edge.save!
      Edge.jwt_edge_id?(edge.api_key.not_nil!.build_jwt).should eq(edge.id)
    end
  end
end
