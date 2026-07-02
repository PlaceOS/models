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

      JSON.parse(asset_type.to_json)["asset_count"].should eq 0
      asset_type.asset_count.should eq 0
    end

    it "enforces name uniqueness scoped to the category" do
      category = Generator.asset_category.save!
      Generator.asset_type(category).tap(&.name = "iPad Pro").save!

      duplicate = Generator.asset_type(category)
      duplicate.name = "iPad Pro"
      duplicate.valid?.should be_false
      duplicate.errors.map(&.field).should contain(:name)
    end

    it "allows the same name under a different category" do
      Generator.asset_type(Generator.asset_category.save!).tap(&.name = "iPad Pro").save!

      other_category = Generator.asset_category.save!
      other = Generator.asset_type(other_category)
      other.name = "iPad Pro"
      other.valid?.should be_true
      other.save!.persisted?.should be_true
    end
  end
end
