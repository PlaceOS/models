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

    it "requires an authority_id" do
      category = Generator.asset_category
      category.authority_id = nil

      category.valid?.should be_false
      category.errors.map(&.field).should contain(:authority_id)
    end

    it "enforces name uniqueness scoped to the authority" do
      authority = Generator.localhost_authority
      Generator.asset_category(authority).tap(&.name = "Tablet").save!

      duplicate = Generator.asset_category(authority)
      duplicate.name = "Tablet"
      duplicate.valid?.should be_false
      duplicate.errors.map(&.field).should contain(:name)
    end

    it "allows the same name under a different authority" do
      Generator.asset_category(Generator.localhost_authority).tap(&.name = "Tablet").save!

      other_authority = Generator.authority(domain: "https://other-asset-cat.example.com").save!
      other = Generator.asset_category(other_authority)
      other.name = "Tablet"
      other.valid?.should be_true
      other.save!.persisted?.should be_true
    end
  end
end
