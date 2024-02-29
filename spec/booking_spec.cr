require "./helper"

module PlaceOS::Model
  Spec.before_each do
    Attendee.clear
    Booking.clear
    Guest.clear
  end

  describe Booking do
    it "returns booking with assets" do
      booking_id = Generator.booking_attendee
      Booking.where(id: booking_id).to_a.size.should eq 1

      query = Booking.where(id: booking_id).join(:left, Attendee, :booking_id).join(:left, Guest, "guests.id = attendees.guest_id")

      booking = query.to_a.first
      booking.attendees.to_a.size.should eq 1

      # ensure we didn't need a second query to fill this in
      guests = booking.__guests_rel
      guests.size.should eq 1
      json_booking = JSON.parse(booking.to_json).as_h
      json_booking["guests"].as_a.size.should eq 1
      json_booking["guests"].as_a.first.as_h["checked_in"]?.should be_false

      check_no_guest = Booking.where(id: booking_id).to_a.first
      JSON.parse(check_no_guest.to_json).as_h["guests"]?.should be_nil

      Attendee.clear
      query_check = Booking.where(id: booking_id).join(:left, Attendee, :booking_id).join(:left, Guest, "guests.id = attendees.guest_id").to_a.first
      query_check.attendees.to_a.size.should eq 0
    end
  end

  it "successfully saves a booking" do
    user_email = "steve@place.tech"
    tenant_id = Generator.tenant.id

    # classic
    booking = Booking.new(
      booking_type: "desk",
      asset_id: "desk1",
      booking_start: 1.hour.from_now.to_unix,
      booking_end: 2.hours.from_now.to_unix,
      user_email: PlaceOS::Model::Email.new(user_email),
      user_name: "Steve",
      booked_by_email: PlaceOS::Model::Email.new(user_email),
      booked_by_name: "Steve",
      tenant_id: tenant_id,
      booked_by_id: "user-1234",
      history: [] of Booking::History
    ).save!
    booking.asset_ids.should eq ["desk1"]
    booking.persisted?.should be_true

    # new
    booking = Booking.new(
      booking_type: "desk",
      asset_ids: ["desk2"],
      booking_start: 1.hour.from_now.to_unix,
      booking_end: 2.hours.from_now.to_unix,
      user_email: PlaceOS::Model::Email.new(user_email),
      user_name: "Steve",
      booked_by_email: PlaceOS::Model::Email.new(user_email),
      booked_by_name: "Steve",
      tenant_id: tenant_id,
      booked_by_id: "user-1234",
      history: [] of Booking::History
    ).save!
    booking.asset_id.should eq "desk2"
    booking.persisted?.should be_true

    # combined
    booking = Booking.new(
      booking_type: "desk",
      asset_id: "desk3",
      asset_ids: ["desk3", "desk4"],
      booking_start: 1.hour.from_now.to_unix,
      booking_end: 2.hours.from_now.to_unix,
      user_email: PlaceOS::Model::Email.new(user_email),
      user_name: "Steve",
      booked_by_email: PlaceOS::Model::Email.new(user_email),
      booked_by_name: "Steve",
      tenant_id: tenant_id,
      booked_by_id: "user-1234",
      history: [] of Booking::History
    ).save!
    booking.asset_ids.should eq ["desk3", "desk4"]
    booking.persisted?.should be_true

    # mismatch 1
    booking = Booking.new(
      booking_type: "desk",
      asset_id: "desk5",
      asset_ids: ["desk6", "desk7"],
      booking_start: 1.hour.from_now.to_unix,
      booking_end: 2.hours.from_now.to_unix,
      user_email: PlaceOS::Model::Email.new(user_email),
      user_name: "Steve",
      booked_by_email: PlaceOS::Model::Email.new(user_email),
      booked_by_name: "Steve",
      tenant_id: tenant_id,
      booked_by_id: "user-1234",
      history: [] of Booking::History
    ).save!
    booking.asset_ids.should eq ["desk6", "desk7"]
    booking.asset_id.should eq "desk6"
    booking.persisted?.should be_true

    # mismatch 2
    booking = Booking.new(
      booking_type: "desk",
      asset_ids: ["desk8"],
      booking_start: 1.hour.from_now.to_unix,
      booking_end: 2.hours.from_now.to_unix,
      user_email: PlaceOS::Model::Email.new(user_email),
      user_name: "Steve",
      booked_by_email: PlaceOS::Model::Email.new(user_email),
      booked_by_name: "Steve",
      tenant_id: tenant_id,
      booked_by_id: "user-1234",
      history: [] of Booking::History
    ).save!
    booking.asset_ids.should eq ["desk8"]
    booking.asset_id.should eq "desk8"
    booking.persisted?.should be_true

    booking.asset_id = "desk9"
    booking.save!
    booking.asset_ids.should eq ["desk9"]
    booking.asset_id.should eq "desk9"
    booking.persisted?.should be_true

    booking.asset_id = "desk10"
    booking.asset_ids = ["desk11"]
    booking.save!
    booking.asset_ids.should eq ["desk11"]
    booking.asset_id.should eq "desk11"
    booking.persisted?.should be_true
  end

  it "rejects a booking that clashes" do
    user_email = "steve@place.tech"
    tenant_id = Generator.tenant.id

    saved = Booking.new(
      booking_type: "desk",
      asset_id: "desk1",
      booking_start: 1.hour.from_now.to_unix,
      booking_end: 2.hours.from_now.to_unix,
      user_email: PlaceOS::Model::Email.new(user_email),
      user_name: "Steve",
      booked_by_email: PlaceOS::Model::Email.new(user_email),
      booked_by_name: "Steve",
      tenant_id: tenant_id,
      booked_by_id: "user-1234",
      history: [] of Booking::History
    ).save!

    # new
    not_saved = Booking.new(
      booking_type: "desk",
      asset_ids: ["desk1"],
      booking_start: 1.hour.from_now.to_unix,
      booking_end: 2.hours.from_now.to_unix,
      user_email: PlaceOS::Model::Email.new(user_email),
      user_name: "Steve",
      booked_by_email: PlaceOS::Model::Email.new(user_email),
      booked_by_name: "Steve",
      tenant_id: tenant_id,
      booked_by_id: "user-1234",
      history: [] of Booking::History
    )
    not_saved.save

    saved.persisted?.should be_true
    not_saved.persisted?.should be_false
  end

  it "rejects a concurrent booking that clashes" do
    user_email = "steve@place.tech"
    tenant_id = Generator.tenant.id

    wait = Channel(Booking).new
    spawn do
      booking = Booking.new(
        booking_type: "desk",
        asset_id: "desk1",
        booking_start: 1.hour.from_now.to_unix,
        booking_end: 2.hours.from_now.to_unix,
        user_email: PlaceOS::Model::Email.new(user_email),
        user_name: "Steve",
        booked_by_email: PlaceOS::Model::Email.new(user_email),
        booked_by_name: "Steve",
        tenant_id: tenant_id,
        booked_by_id: "user-1234",
        history: [] of Booking::History
      )
      booking.save
      wait.send booking
    end

    local = Booking.new(
      booking_type: "desk",
      asset_ids: ["desk1"],
      booking_start: 1.hour.from_now.to_unix,
      booking_end: 2.hours.from_now.to_unix,
      user_email: PlaceOS::Model::Email.new(user_email),
      user_name: "Steve",
      booked_by_email: PlaceOS::Model::Email.new(user_email),
      booked_by_name: "Steve",
      tenant_id: tenant_id,
      booked_by_id: "user-1234",
      history: [] of Booking::History
    )
    local.save

    spawned = wait.receive
    saved = 0
    saved += 1 if local.persisted?
    saved += 1 if spawned.persisted?

    saved.should eq 1
  end

  it "rejects a booking with multiple same asset ids" do
    user_email = "steve@place.tech"
    tenant_id = Generator.tenant.id

    local = Booking.new(
      booking_type: "desk",
      asset_ids: ["desk1", "desk2", "desk1"],
      booking_start: 1.hour.from_now.to_unix,
      booking_end: 2.hours.from_now.to_unix,
      user_email: PlaceOS::Model::Email.new(user_email),
      user_name: "Steve",
      booked_by_email: PlaceOS::Model::Email.new(user_email),
      booked_by_name: "Steve",
      tenant_id: tenant_id,
      booked_by_id: "user-1234",
      history: [] of Booking::History
    )
    local.save.should be_false
    local.persisted?.should be_false
  end
end
