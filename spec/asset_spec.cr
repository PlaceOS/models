require "./helper"

module PlaceOS::Model
  describe Asset do
    Spec.before_each do
      Asset.clear
      Booking.clear
    end

    test_round_trip(Asset)

    it "saves an Asset" do
      asset = Generator.asset.save!

      asset.should_not be_nil
      asset.persisted?.should be_true
      Asset.find!(asset.id).id.should eq asset.id

      asset_type = asset.asset_type.as(AssetType)
      JSON.parse(asset_type.to_json)["asset_count"].should eq 1
      asset_type.asset_count.should eq 1
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

      asset = Asset.new(
        asset_type_id: asset_type.id,
        zone_id: asset_zone.id,
        other_data: JSON.parse("{}")
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

    it "handles multiple assets per booking" do
      asset = Generator.asset.save!
      asset2 = Generator.asset.save!

      tenant = get_tenant
      event_start = 5.minutes.from_now
      event_end = 10.minutes.from_now
      asset_id = asset.id.as(String)
      booking = Generator.booking(tenant.id, asset_id, event_start, event_end)
      booking.save!

      booking.asset_ids.size.should eq(1)
      booking.asset_ids.first.should eq(booking.asset_id)

      booking.asset_id = asset2.id.as(String)
      booking.save!

      booking.asset_ids.size.should eq(2)
      booking.asset_id.should eq(asset2.id)
    end

    it "handles asset_ids enries" do
      asset = Generator.asset.save!
      asset2 = Generator.asset.save!

      tenant = get_tenant
      event_start = 5.minutes.from_now
      event_end = 10.minutes.from_now
      asset_ids = [asset.id.as(String), asset2.id.as(String)]
      booking = Generator.booking(tenant.id, asset_ids, event_start, event_end)
      booking.save!

      booking.asset_ids.size.should eq(2)
      booking.asset_ids.first.should eq(booking.asset_id)
      booking.asset_id.should eq(asset.id)

      asset_ids.reverse!
      booking.asset_ids = asset_ids
      booking.save!
      booking.asset_ids.size.should eq(2)
      booking.asset_ids.first.should eq(booking.asset_id)
      booking.asset_id.should eq(asset2.id)
    end
  end
end
