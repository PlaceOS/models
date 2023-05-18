require "./helper"

module PlaceOS::Model
  Spec.before_each do
    AssetCategory.clear
  end

  describe AssetCategory do
    test_round_trip(AssetCategory)

    it "saves an Asset" do
      asset_category = Generator.asset_category.save!

      asset_category.should_not be_nil
      asset_category.persisted?.should be_true
      AssetCategory.find!(asset_category.id).id.should eq asset_category.id
    end
  end
end
