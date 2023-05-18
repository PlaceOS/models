require "./helper"

module PlaceOS::Model
  Spec.before_each do
    Asset.clear
  end

  describe Asset do
    test_round_trip(Asset)

    it "saves an Asset" do
      asset = Generator.asset.save!

      asset.should_not be_nil
      asset.persisted?.should be_true
      Asset.find!(asset.id.as(String)).id.should eq asset.id
    end
  end
end
