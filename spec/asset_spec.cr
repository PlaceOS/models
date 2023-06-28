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
      Asset.find!(asset.id).id.should eq asset.id
    end

    it "saves a minimal Asset" do
      asset_zone = Generator.zone.save!
      asset_type = Generator.asset_type.save!

      asset = Asset.new(
        asset_type_id: asset_type.id,
        zone_id: asset_zone.id,
      )
      asset.save!

      asset.should_not be_nil
      asset.persisted?.should be_true
      Asset.find!(asset.id).id.should eq asset.id
    end

    it "books an asset" do
      asset = Generator.asset.save!

      asset.should_not be_nil
      asset.persisted?.should be_true
      Asset.find!(asset.id).id.should eq asset.id

      tenant = get_tenant
      event_start = 5.minutes.from_now
      event_end = 10.minutes.from_now
      asset_id = asset.id.as(String)
      booking = Generator.booking(tenant.id, asset_id, event_start, event_end)
      booking.save!

      asset.destroy
      booking.reload!
      booking.rejected.should be_true
    end
  end
end
