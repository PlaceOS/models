require "./helper"

module PlaceOS::Model
  describe BookingInstance do
    timezone = Time::Location.load("Europe/Berlin")
    start_time = Time.local(2020, 1, 10, 10, 0, 0, location: timezone)
    end_time = start_time + 1.hour
    start_query = Time.local(2020, 1, 5, 5, 0, 0, location: timezone)
    end_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)

    booking = Generator.booking(
      1_i64,
      asset_id: "desk-1234",
      start: start_time,
      ending: end_time
    )

    Spec.before_each do
      Booking.clear
      Tenant.clear
      booking = Generator.booking(
        1_i64,
        asset_id: "desk-1234",
        start: start_time,
        ending: end_time
      )
      booking.timezone = "Europe/Berlin"
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
    end

    it "persists custom approval fields on an instance and hydrates them" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.save!
      times = booking.calculate_daily(start_query, end_query).instances

      booking_instance = booking.to_instance(times[1].to_unix)
      booking_instance.rejected = true
      booking_instance.rejected_at = times[1].to_unix
      booking_instance.approver_id = "approver-1"
      booking_instance.approver_name = "Appro Ver"
      booking_instance.approver_email = "approver@example.com"
      booking_instance.save!

      reloaded = BookingInstance
        .where(id: booking.id.as(Int64), instance_start: times[1].to_unix)
        .first
      reloaded.rejected.should eq true
      reloaded.rejected_at.should eq times[1].to_unix
      reloaded.approved.should be_nil
      reloaded.approver_id.should eq "approver-1"
      reloaded.approver_name.should eq "Appro Ver"
      reloaded.approver_email.should eq "approver@example.com"

      hydrated = reloaded.hydrate_booking(booking)
      hydrated.rejected.should eq true
      hydrated.rejected_at.should eq times[1].to_unix
      hydrated.approved.should eq false
      hydrated.approver_name.should eq "Appro Ver"

      # expansion should reflect the override on just that occurrence
      bookings = [booking]
      Booking.expand_bookings!(start_query, end_query, bookings)
      bookings.map(&.starting_tz.day).should eq [10, 11, 12]
      bookings.map(&.rejected).should eq [false, true, false]
      bookings.map(&.approver_name).should eq [nil, "Appro Ver", nil]
    end

    it "inherits parent approval state unless the instance overrides it as a group" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.approved = true
      booking.approved_at = start_time.to_unix
      booking.approver_name = "Boss"
      booking.save!
      times = booking.calculate_daily(start_query, end_query).instances

      # no override, inherit everything
      booking_instance = booking.to_instance(times[1].to_unix)
      hydrated = booking_instance.hydrate_booking(booking)
      hydrated.approved.should eq true
      hydrated.approver_name.should eq "Boss"

      # a custom rejection replaces the whole approval group, so the
      # parent's approval state and approver details don't bleed through
      booking_instance.rejected = true
      hydrated = booking_instance.hydrate_booking(booking)
      hydrated.rejected.should eq true
      hydrated.approved.should eq false
      hydrated.approved_at.should be_nil
      hydrated.approver_name.should be_nil
    end

    it "frees the slot for regular bookings when an instance is rejected" do
      tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.tenant_id = tenant_id
      booking.save!
      times = booking.calculate_daily(start_query, end_query).instances

      booking_instance = booking.to_instance(times[1].to_unix)
      booking_instance.rejected = true
      booking_instance.rejected_at = Time.utc.to_unix
      booking_instance.save!

      # the rejected occurrence no longer blocks the asset
      clashing = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: times[1],
        ending: times[1] + 1.hour,
      )
      clashing.timezone = "Europe/Berlin"
      clashing.save.should eq true

      # other occurrences still do
      clashing = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: times[2],
        ending: times[2] + 1.hour,
      )
      clashing.timezone = "Europe/Berlin"
      clashing.save.should eq false
    end

    it "frees the slot for recurring bookings when an instance is rejected" do
      tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.tenant_id = tenant_id
      booking.save!
      times = booking.calculate_daily(start_query, end_query).instances

      # a single occurrence recurring booking on the same asset clashes
      single = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: times[1],
        ending: times[1] + 1.hour,
      )
      single.timezone = "Europe/Berlin"
      single.recurrence_type = :daily
      single.recurrence_days = 0b1111111
      single.recurrence_end = (times[1] + 13.hours).to_unix
      single.save.should eq false

      # reject the occurrence and the same recurring booking saves
      booking_instance = booking.to_instance(times[1].to_unix)
      booking_instance.rejected = true
      booking_instance.save!

      single = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: times[1],
        ending: times[1] + 1.hour,
      )
      single.timezone = "Europe/Berlin"
      single.recurrence_type = :daily
      single.recurrence_days = 0b1111111
      single.recurrence_end = (times[1] + 13.hours).to_unix
      single.save.should eq true
    end

    it "moves a single occurrence onto different assets (regular clash checks)" do
      tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.tenant_id = tenant_id
      booking.save!
      times = booking.calculate_daily(start_query, end_query).instances

      booking_instance = booking.to_instance(times[1].to_unix)
      booking_instance.asset_ids = ["desk-5678"]
      booking_instance.save!

      reloaded = BookingInstance
        .where(id: booking.id.as(Int64), instance_start: times[1].to_unix)
        .first
      reloaded.asset_ids.should eq ["desk-5678"]
      reloaded.asset_id.should eq "desk-5678"
      reloaded.hydrate_booking(booking).asset_ids.should eq ["desk-5678"]

      # the original asset is free for that occurrence only
      on_old_asset = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: times[1],
        ending: times[1] + 1.hour,
      )
      on_old_asset.timezone = "Europe/Berlin"

      # though when ignoring assets the occurrence still registers a clash
      on_old_asset.clashing_bookings(ignore_assets: true).should_not be_empty
      on_old_asset.save.should eq true

      # the new asset is now blocked for that occurrence
      on_new_asset = Generator.booking(
        tenant_id,
        asset_id: "desk-5678",
        start: times[1],
        ending: times[1] + 1.hour,
      )
      on_new_asset.timezone = "Europe/Berlin"
      on_new_asset.save.should eq false

      # the new asset is free at other occurrences
      on_new_asset = Generator.booking(
        tenant_id,
        asset_id: "desk-5678",
        start: times[2],
        ending: times[2] + 1.hour,
      )
      on_new_asset.timezone = "Europe/Berlin"
      on_new_asset.save.should eq true

      # the original asset is still blocked at other occurrences
      on_old_asset = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: times[0],
        ending: times[0] + 1.hour,
      )
      on_old_asset.timezone = "Europe/Berlin"
      on_old_asset.save.should eq false
    end

    it "moves a single occurrence onto different assets (recurring clash checks)" do
      tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.tenant_id = tenant_id
      booking.save!
      times = booking.calculate_daily(start_query, end_query).instances

      booking_instance = booking.to_instance(times[1].to_unix)
      booking_instance.asset_ids = ["desk-5678"]
      booking_instance.save!

      # a recurring booking on the new asset clashes with the moved occurrence
      single = Generator.booking(
        tenant_id,
        asset_id: "desk-5678",
        start: times[1],
        ending: times[1] + 1.hour,
      )
      single.timezone = "Europe/Berlin"
      single.recurrence_type = :daily
      single.recurrence_days = 0b1111111
      single.recurrence_end = (times[1] + 13.hours).to_unix
      single.save.should eq false

      # a recurring booking on the original asset is clear of the moved occurrence
      single = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: times[1],
        ending: times[1] + 1.hour,
      )
      single.timezone = "Europe/Berlin"
      single.recurrence_type = :daily
      single.recurrence_days = 0b1111111
      single.recurrence_end = (times[1] + 13.hours).to_unix
      single.save.should eq true
    end

    it "rejects an instance asset override that clashes with an existing booking" do
      tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.tenant_id = tenant_id
      booking.save!
      times = booking.calculate_daily(start_query, end_query).instances

      # a regular booking on another asset at the same time
      other = Generator.booking(
        tenant_id,
        asset_id: "desk-7777",
        start: times[1],
        ending: times[1] + 1.hour,
      )
      other.timezone = "Europe/Berlin"
      other.save.should eq true

      # moving the occurrence onto that asset must fail validation
      booking_instance = booking.to_instance(times[1].to_unix)
      booking_instance.asset_ids = ["desk-7777"]
      booking_instance.save.should eq false
      booking_instance.errors.map(&.field).should contain(:booking_start)
    end

    it "saves approval and asset overrides transparently via Booking#save" do
      tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.tenant_id = tenant_id
      booking.save!
      times = booking.calculate_daily(start_query, end_query).instances

      bookings = [booking]
      Booking.expand_bookings!(start_query, end_query, bookings)
      hydrated = bookings[1]
      hydrated.instance.should eq times[1].to_unix

      hydrated.approved = true
      hydrated.approved_at = times[1].to_unix
      hydrated.approver_id = "approver-2"
      hydrated.approver_name = "Insta Approver"
      hydrated.approver_email = "insta@example.com"
      hydrated.asset_ids = ["desk-9999"]
      hydrated.save!

      reloaded = BookingInstance
        .where(id: booking.id.as(Int64), instance_start: times[1].to_unix)
        .first
      reloaded.approved.should eq true
      reloaded.approved_at.should eq times[1].to_unix
      reloaded.rejected.should be_nil
      reloaded.approver_id.should eq "approver-2"
      reloaded.approver_name.should eq "Insta Approver"
      reloaded.approver_email.should eq "insta@example.com"
      reloaded.asset_ids.should eq ["desk-9999"]
      reloaded.asset_id.should eq "desk-9999"

      # the overrides come through on the next expansion
      bookings = [Booking.find(booking.id.as(Int64))]
      Booking.expand_bookings!(start_query, end_query, bookings)
      bookings.map(&.approved).should eq [false, true, false]
      bookings.map(&.asset_id).should eq ["desk-1234", "desk-9999", "desk-1234"]
    end

    it "keeps instance asset_id and asset_ids in sync" do
      tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.tenant_id = tenant_id
      booking.save!
      times = booking.calculate_daily(start_query, end_query).instances

      # setting just the asset_id populates asset_ids
      booking_instance = booking.to_instance(times[1].to_unix)
      booking_instance.asset_id = "desk-5678"
      booking_instance.save!
      reloaded = BookingInstance
        .where(id: booking.id.as(Int64), instance_start: times[1].to_unix)
        .first
      reloaded.asset_ids.should eq ["desk-5678"]
      reloaded.asset_id.should eq "desk-5678"

      # clearing the list removes the override entirely
      reloaded.asset_ids = [] of String
      reloaded.save!
      reloaded = BookingInstance
        .where(id: booking.id.as(Int64), instance_start: times[1].to_unix)
        .first
      reloaded.asset_ids.should be_nil
      reloaded.asset_id.should be_nil
      reloaded.hydrate_booking(booking).asset_ids.should eq ["desk-1234"]

      # duplicate ids are invalid
      reloaded.asset_ids = ["desk-1", "desk-1"]
      reloaded.save.should eq false
      reloaded.errors.map(&.field).should contain(:asset_ids)
    end
  end
end
