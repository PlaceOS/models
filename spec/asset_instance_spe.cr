require "./helper"

module PlaceOS::Model
  describe AssetInstance do
    it "saves a AssetInstance" do
      asset = Generator.asset.save!

      inst = Generator.asset_instance(asset).save!
      id = AssetInstance.find!(inst.id.as(String)).id
      id.should eq inst.id
    end

    describe "index view" do
      it "#of finds AssetInstance by parent Asset" do
        inst = Generator.asset_instance.save!
        asset = inst.asset.as(Asset)

        id = AssetInstance.of(asset.id.as(String)).first?.try(&.id)
        id.should eq inst.id
      end
    end
  end
end
