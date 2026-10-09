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

    it "requires an authority" do
      purchase_order = Generator.asset_purchase_order
      purchase_order.authority_id = nil
      purchase_order.valid?.should be_false
      purchase_order.errors.map(&.field).should contain(:authority_id)
    end

    it "is deleted when its authority is deleted" do
      authority = Generator.authority(domain: "po-cascade-#{RANDOM.hex(4)}.dev").save!
      purchase_order = Generator.asset_purchase_order(authority: authority).save!

      authority.delete
      AssetPurchaseOrder.find?(purchase_order.id).should be_nil
    end

    it "keeps its assets when deleted, clearing their purchase_order_id" do
      purchase_order = Generator.asset_purchase_order.save!
      asset = Generator.asset(purchase_order: purchase_order).save!
      asset.purchase_order_id.should eq purchase_order.id

      purchase_order.delete
      reloaded = Asset.find!(asset.id)
      reloaded.purchase_order_id.should be_nil
    end
  end
end
