require "./helper"

module PlaceOS::Model
  describe Asset do
    it "saves an asset" do
      asset = Generator.asset

      begin
        asset.save!
      rescue e : RethinkORM::Error::DocumentInvalid
        inspect_error(e)
        raise e
      end

      asset.should_not be_nil
      id = asset.id
      id.should start_with "asset-" if id
      asset.persisted?.should be_true
    end

    it "cannot use more than quantity" do
      expect_raises(RethinkORM::Error::DocumentInvalid) do
        asset = Generator.asset
        asset.quantity = 20
        asset.save!
        asset.in_use = asset.quantity + 1
        asset.save!
      end
    end

    it "saves other data" do
      asset = Generator.asset
      asset.other_data = JSON.parse(%({"fizz": 1, "bizz": 2}))
      asset.other_data["fizz"].should eq(1)
    end
  end
end
