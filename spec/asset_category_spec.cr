require "./helper"

module PlaceOS::Model
  Spec.before_each do
    AssetCategory.clear
  end

  describe AssetCategory do
    test_round_trip(AssetCategory)

    it "preserves a JSON string stored in the description field" do
      json_description = %({"resource_type":"locker_banks","created_at":1765438626035})
      asset_category = Generator.asset_category
      asset_category.description = json_description
      asset_category.save!

      reloaded = AssetCategory.find!(asset_category.id)
      reloaded.description.should eq json_description
    end

    it "saves an Asset" do
      asset_category = Generator.asset_category.save!

      asset_category.should_not be_nil
      asset_category.persisted?.should be_true
      AssetCategory.find!(asset_category.id).id.should eq asset_category.id
    end
  end
end
