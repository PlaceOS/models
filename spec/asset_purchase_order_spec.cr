require "./helper"

module PlaceOS::Model
  Spec.before_each do
    AssetPurchaseOrder.clear
  end

  describe AssetPurchaseOrder do
    test_round_trip(AssetPurchaseOrder)

    it "saves an Asset" do
      asset_purchase_order = Generator.asset_purchase_order.save!

      asset_purchase_order.should_not be_nil
      asset_purchase_order.persisted?.should be_true
      AssetPurchaseOrder.find!(asset_purchase_order.id).id.should eq asset_purchase_order.id
    end
  end
end
