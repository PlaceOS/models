require "./helper"

module PlaceOS::Model
  describe Asset do
    test_round_trip(Asset)

    it "saves an asset" do
      asset = Generator.asset.save!
      asset.should_not be_nil
      id = asset.id
      id.should start_with "asset-" if id
      asset.persisted?.should be_true
    end

    describe "validations" do
      it "in_use <= quantity" do
        expect_raises(RethinkORM::Error::DocumentInvalid) do
          asset = Generator.asset
          asset.quantity = 20
          asset.save!
          asset.in_use = asset.quantity + 1
          asset.save!
        end
      end
    end

    describe "#consumable_assets" do
      it "supports associated consumable assets" do
        asset = Generator.asset.save!
        asset.should_not be_nil
        id = asset.id.as(String)
        id.should start_with "asset-"
        asset.persisted?.should be_true

        asset2 = Generator.asset
        asset2.parent_id = id
        asset2.save!

        id2 = asset2.id.as(String)
        id2.should start_with "asset-"

        asset.consumable_assets.not_nil!.to_a.map(&.id).should eq [id2]
        asset2.parent!.id.should eq id
      end
    end

    it "saves other data" do
      asset = Generator.asset
      asset.other_data = JSON.parse(%({"fizz": 1, "bizz": 2}))
      asset.other_data["fizz"].should eq(1)
    end
  end
end
