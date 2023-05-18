require "./helper"

module PlaceOS::Model
  Spec.before_each do
    AssetType.clear
  end

  describe AssetType do
    test_round_trip(AssetType)

    it "saves an Asset" do
      asset_type = Generator.asset_type.save!

      asset_type.should_not be_nil
      asset_type.persisted?.should be_true
      AssetType.find!(asset_type.id).id.should eq asset_type.id
    end
  end
end
