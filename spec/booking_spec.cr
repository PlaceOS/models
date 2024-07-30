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

    it "returns bookings by_user_or_email" do
      tenant_id = Generator.tenant.id

      user_one_email = "one@example.com"
      user_two_email = "two@example.com"

      bookings = [] of Booking

      # user one private group-event
      bookings << Booking.new(
        booking_type: "group-event",
        asset_ids: ["room-1"],
        booking_start: 1.hour.from_now.to_unix,
        booking_end: 2.hours.from_now.to_unix,
        user_email: PlaceOS::Model::Email.new(user_one_email),
        user_name: "One",
        booked_by_email: PlaceOS::Model::Email.new(user_one_email),
        booked_by_name: "One",
        tenant_id: tenant_id,
        booked_by_id: "user-1",
        history: [] of Booking::History,
        permission: Booking::Permission::PRIVATE
      ).save!

      # user two private group-event
      bookings << Booking.new(
        booking_type: "group-event",
        asset_ids: ["room-4"],
        booking_start: 1.hour.from_now.to_unix,
        booking_end: 2.hours.from_now.to_unix,
        user_email: PlaceOS::Model::Email.new(user_two_email),
        user_name: "Two",
        booked_by_email: PlaceOS::Model::Email.new(user_two_email),
        booked_by_name: "Two",
        tenant_id: tenant_id,
        booked_by_id: "user-2",
        history: [] of Booking::History,
        permission: Booking::Permission::PRIVATE
      ).save!

      query = Booking
        .by_tenant(tenant_id)
        .by_user_or_email(nil, user_one_email, true)

      list = query.to_a
      list.size.should eq 1
      list.map(&.id).should contain(bookings[0].id)
      list.map(&.id).should_not contain(bookings[1].id)
    end

    it "returns bookings by_user_or_email including open and public permissions" do
      tenant_id = Generator.tenant.id

      user_one_email = "one@example.com"
      user_two_email = "two@example.com"

      bookings = [] of Booking

      # user one private group-event
      bookings << Booking.new(
        booking_type: "group-event",
        asset_ids: ["room-1"],
        booking_start: 1.hour.from_now.to_unix,
        booking_end: 2.hours.from_now.to_unix,
        user_email: PlaceOS::Model::Email.new(user_one_email),
        user_name: "One",
        booked_by_email: PlaceOS::Model::Email.new(user_one_email),
        booked_by_name: "One",
        tenant_id: tenant_id,
        booked_by_id: "user-1",
        history: [] of Booking::History,
        permission: Booking::Permission::PRIVATE
      ).save!

      # user one open group-event
      bookings << Booking.new(
        booking_type: "group-event",
        asset_ids: ["room-2"],
        booking_start: 1.hour.from_now.to_unix,
        booking_end: 2.hours.from_now.to_unix,
        user_email: PlaceOS::Model::Email.new(user_one_email),
        user_name: "One",
        booked_by_email: PlaceOS::Model::Email.new(user_one_email),
        booked_by_name: "One",
        tenant_id: tenant_id,
        booked_by_id: "user-1",
        history: [] of Booking::History,
        permission: Booking::Permission::OPEN
      ).save!

      # user one public group-event
      bookings << Booking.new(
        booking_type: "group-event",
        asset_ids: ["room-3"],
        booking_start: 1.hour.from_now.to_unix,
        booking_end: 2.hours.from_now.to_unix,
        user_email: PlaceOS::Model::Email.new(user_one_email),
        user_name: "One",
        booked_by_email: PlaceOS::Model::Email.new(user_one_email),
        booked_by_name: "One",
        tenant_id: tenant_id,
        booked_by_id: "user-1",
        history: [] of Booking::History,
        permission: Booking::Permission::PUBLIC
      ).save!

      # user two private group-event
      bookings << Booking.new(
        booking_type: "group-event",
        asset_ids: ["room-4"],
        booking_start: 1.hour.from_now.to_unix,
        booking_end: 2.hours.from_now.to_unix,
        user_email: PlaceOS::Model::Email.new(user_two_email),
        user_name: "Two",
        booked_by_email: PlaceOS::Model::Email.new(user_two_email),
        booked_by_name: "Two",
        tenant_id: tenant_id,
        booked_by_id: "user-2",
        history: [] of Booking::History,
        permission: Booking::Permission::PRIVATE
      ).save!

      # user two open group-event
      bookings << Booking.new(
        booking_type: "group-event",
        asset_ids: ["room-5"],
        booking_start: 1.hour.from_now.to_unix,
        booking_end: 2.hours.from_now.to_unix,
        user_email: PlaceOS::Model::Email.new(user_two_email),
        user_name: "Two",
        booked_by_email: PlaceOS::Model::Email.new(user_two_email),
        booked_by_name: "Two",
        tenant_id: tenant_id,
        booked_by_id: "user-2",
        history: [] of Booking::History,
        permission: Booking::Permission::OPEN
      ).save!

      # user two public group-event
      bookings << Booking.new(
        booking_type: "group-event",
        asset_ids: ["room-6"],
        booking_start: 1.hour.from_now.to_unix,
        booking_end: 2.hours.from_now.to_unix,
        user_email: PlaceOS::Model::Email.new(user_two_email),
        user_name: "Two",
        booked_by_email: PlaceOS::Model::Email.new(user_two_email),
        booked_by_name: "Two",
        tenant_id: tenant_id,
        booked_by_id: "user-2",
        history: [] of Booking::History,
        permission: Booking::Permission::PUBLIC
      ).save!

      query = Booking
        .by_tenant(tenant_id)
        .by_user_or_email(nil, user_one_email, true)

      list = query.to_a
      list.size.should eq 3
      list.map(&.id).should contain(bookings[0].id)
      list.map(&.id).should contain(bookings[1].id)
      list.map(&.id).should contain(bookings[2].id)
      list.map(&.id).should_not contain(bookings[3].id)
      list.map(&.id).should_not contain(bookings[4].id)
      list.map(&.id).should_not contain(bookings[5].id)

      query = Booking
        .by_tenant(tenant_id)
        .by_user_or_email(nil, user_one_email, true, include_open_permission: true, include_public_permission: false)

      list = query.to_a
      list.size.should eq 4
      list.map(&.id).should contain(bookings[0].id)
      list.map(&.id).should contain(bookings[1].id)
      list.map(&.id).should contain(bookings[2].id)
      list.map(&.id).should_not contain(bookings[3].id)
      list.map(&.id).should contain(bookings[4].id)
      list.map(&.id).should_not contain(bookings[5].id)

      query = Booking
        .by_tenant(tenant_id)
        .by_user_or_email(nil, user_one_email, true, include_open_permission: false, include_public_permission: true)

      list = query.to_a
      list.size.should eq 4
      list.map(&.id).should contain(bookings[0].id)
      list.map(&.id).should contain(bookings[1].id)
      list.map(&.id).should contain(bookings[2].id)
      list.map(&.id).should_not contain(bookings[3].id)
      list.map(&.id).should_not contain(bookings[4].id)
      list.map(&.id).should contain(bookings[5].id)

      query = Booking
        .by_tenant(tenant_id)
        .by_user_or_email(nil, user_one_email, true, include_open_permission: true, include_public_permission: true)

      list = query.to_a
      list.size.should eq 5
      list.map(&.id).should contain(bookings[0].id)
      list.map(&.id).should contain(bookings[1].id)
      list.map(&.id).should contain(bookings[2].id)
      list.map(&.id).should_not contain(bookings[3].id)
      list.map(&.id).should contain(bookings[4].id)
      list.map(&.id).should contain(bookings[5].id)
    end

    it "returns bookings by_user_or_email including guest attendee" do
      tenant_id = Generator.tenant.id

      user_one_email = "one@example.com"
      user_two_email = "two@example.com"

      bookings = [] of Booking

      bookings << Booking.new(
        booking_type: "group-event",
        asset_ids: ["room-1"],
        booking_start: 1.hour.from_now.to_unix,
        booking_end: 2.hours.from_now.to_unix,
        user_email: PlaceOS::Model::Email.new(user_one_email),
        user_name: "One",
        booked_by_email: PlaceOS::Model::Email.new(user_one_email),
        booked_by_name: "One",
        tenant_id: tenant_id,
        booked_by_id: "user-1",
        history: [] of Booking::History,
        permission: Booking::Permission::OPEN
      ).save!

      user_two_guest = Guest.new(
        email: user_two_email,
        name: "Two",
        tenant_id: tenant_id
      ).save!

      user_two_attendee = Attendee.new(
        booking_id: bookings[0].id,
        guest_id: user_two_guest.id,
        tenant_id: tenant_id,
        checked_in: false,
        visit_expected: true,
      ).save!

      bookings << Booking.new(
        booking_type: "group-event",
        asset_ids: ["room-2"],
        booking_start: 2.hour.from_now.to_unix,
        booking_end: 3.hours.from_now.to_unix,
        user_email: PlaceOS::Model::Email.new(user_one_email),
        user_name: "One",
        booked_by_email: PlaceOS::Model::Email.new(user_one_email),
        booked_by_name: "One",
        tenant_id: tenant_id,
        booked_by_id: "user-1",
        history: [] of Booking::History,
        permission: Booking::Permission::OPEN
      ).save!

      query = Booking
        .by_tenant(tenant_id)
        .by_user_or_email(nil, user_two_email, true, false, false, true)

      list = query.to_a
      list.size.should eq 1
      list.map(&.id).should contain(bookings[0].id)
      list.map(&.id).should_not contain(bookings[1].id)
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

  it "should work when run in a transaction" do
    PgORM::Database.transaction do |tx|
      tx.connection.exec("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE")

      user_email = "steve@place.tech"
      tenant_id = Generator.tenant.id

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
    end
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

  it "rejects a booking with the same start and end times" do
    user_email = "steve@place.tech"
    tenant_id = Generator.tenant.id
    start_time = 1.hour.from_now.to_unix

    booking = Booking.new(
      booking_type: "desk",
      asset_ids: ["desk2"],
      booking_start: start_time,
      booking_end: start_time,
      user_email: PlaceOS::Model::Email.new(user_email),
      user_name: "Steve",
      booked_by_email: PlaceOS::Model::Email.new(user_email),
      booked_by_name: "Steve",
      tenant_id: tenant_id,
      booked_by_id: "user-1234",
      history: [] of Booking::History
    )
    booking.save.should be_false
    booking.persisted?.should be_false
  end
end
