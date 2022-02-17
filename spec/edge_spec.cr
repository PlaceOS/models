require "./helper"

module PlaceOS::Model
  describe Edge do
    it ".create" do
      create_body = Edge::CreateBody.new(Faker::Name.name)
      user = Generator.user.save!
      Edge.create(create_body, user)
    end

    it "saves an Edge" do
      edge = Generator.edge.save!

      edge.should_not be_nil
      edge.persisted?.should be_true
      Edge.find!(edge.id.as(String)).id.should eq edge.id
    end

    it "generates a token for the edge" do
      create_body = Edge::CreateBody.new(Faker::Name.name)
      user = Generator.user.save!
      edge = Edge.create(create_body, user)
      Edge.jwt_edge_id?(edge.api_key.not_nil!.build_jwt).should eq(edge.id)
    end
  end
end
