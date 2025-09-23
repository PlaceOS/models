require "./helper"

module PlaceOS::Model
  describe Booking do
    timezone = Time::Location.load("Europe/Berlin")
    start_time = Time.local(2020, 1, 10, 10, 0, 0, location: timezone)
    end_time = start_time + 1.hour
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
    end

    it "recurring bookings require a timezone" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.timezone = ""
      booking.save.should be_false

      booking.timezone = nil
      booking.save.should be_false

      booking.timezone = "Berttty"
      booking.save.should be_false

      booking.timezone = "Europe/Berlin"
      booking.save.should be_true
    end

    it "should have a booking every day" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      start_query = Time.local(2020, 1, 15, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 20, 0, 0, 0, location: timezone)
      details = booking.calculate_daily(start_query, end_query)
      details.limit_reached.should eq false
      times = details.instances
      times.each(&.hour.should(eq(10)))
      times.map(&.day).should eq [15, 16, 17, 18, 19]
    end

    it "checks for bookings where the query starts in the past (overlapping)" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      start_query = Time.local(2020, 1, 5, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query).instances
      times.each(&.hour.should(eq(10)))
      times.map(&.day).should eq [10, 11, 12]
    end

    it "checks for bookings where the query starts in the past (no overlap)" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      start_query = Time.local(2020, 1, 1, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 10, 5, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query).instances
      times.size.should eq 0
    end

    it "checks intervals work as expected" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.recurrence_interval = 2
      booking.save!

      start_query = Time.local(2020, 1, 5, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 20, 5, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query).instances
      times.each(&.hour.should(eq(10)))
      times.map(&.day).should eq [10, 12, 14, 16, 18]

      start_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 20, 5, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query).instances
      times.each(&.hour.should(eq(10)))
      times.map(&.day).should eq [14, 16, 18]
    end

    it "checks for bookings that should only land on weekdays" do
      # start_query is a wednesday
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b0111110
      booking.save!

      start_query = Time.local(2020, 1, 15, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 20, 0, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query).instances
      times.each(&.hour.should(eq(10)))
      times.map(&.day).should eq [15, 16, 17]
    end

    it "checks bookings cut off on recurrence end date" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_end = Time.local(2020, 1, 17, 0, 0, 0, location: timezone).to_unix
      booking.recurrence_days = 0b0111110
      booking.save!

      start_query = Time.local(2020, 1, 15, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 20, 0, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query).instances
      times.each(&.hour.should(eq(10)))
      times.map(&.day).should eq [15, 16]
    end

    it "generates correct times for weekly recurring bookings" do
      new_start_time = Time.local(2020, 1, 1, 10, 0, 0, location: timezone)
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.booking_start = new_start_time.to_unix
      booking.booking_end = (new_start_time + 1.hour).to_unix
      booking.recurrence_type = :weekly
      booking.recurrence_days = 0b1111111
      booking.save!

      # should have a booking every week
      start_query = Time.local(2020, 1, 5, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 2, 1, 0, 0, 0, location: timezone)
      times = booking.calculate_weekly(start_query, end_query).instances
      times.each(&.hour.should(eq(10)))
      times.map(&.day).should eq [8, 15, 22, 29]

      # should have a booking every week overlap query
      start_query = Time.local(2019, 12, 10, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 2, 1, 0, 0, 0, location: timezone)
      times = booking.calculate_weekly(start_query, end_query).instances
      times.each(&.hour.should(eq(10)))
      times.map(&.day).should eq [1, 8, 15, 22, 29]
    end

    it "should allow a booking every month" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :monthly
      booking.recurrence_days = 0b1111111
      booking.recurrence_nth_of_month = 2
      booking.save!

      start_query = Time.local(2020, 1, 15, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 5, 20, 0, 0, 0, location: timezone)
      details = booking.calculate_monthly(start_query, end_query)
      details.limit_reached.should eq false
      times = details.instances
      times.each(&.hour.should(eq(10)))
      times.map(&.day).should eq [8, 8, 8, 8]
    end

    it "should allow a booking the 2nd friday of each month" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :monthly
      booking.recurrence_days = 0b0100000
      booking.recurrence_nth_of_month = 2
      booking.save!

      start_query = Time.local(2020, 1, 15, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 5, 20, 0, 0, 0, location: timezone)
      times = booking.calculate_monthly(start_query, end_query).instances
      times.each(&.hour.should(eq(10)))
      times.map(&.day).should eq [14, 13, 10, 8]
    end

    it "should allow booking the 2nd friday of each month, query overlap" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :monthly
      booking.recurrence_days = 0b0100000
      booking.recurrence_nth_of_month = 2
      booking.save!

      start_query = Time.local(2019, 1, 15, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 5, 20, 0, 0, 0, location: timezone)
      times = booking.calculate_monthly(start_query, end_query).instances
      times.each(&.hour.should(eq(10)))
      times.map(&.day).should eq [10, 14, 13, 10, 8]
    end

    it "should allow booking the 2nd friday of each month, much in the future" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :monthly
      booking.recurrence_days = 0b0100000
      booking.recurrence_nth_of_month = 2
      booking.save!

      start_query = Time.local(2024, 1, 15, 0, 0, 0, location: timezone)
      end_query = Time.local(2024, 5, 20, 0, 0, 0, location: timezone)
      times = booking.calculate_monthly(start_query, end_query).instances
      times.each(&.hour.should(eq(10)))
      times.map(&.day).should eq [9, 8, 12, 10]
    end

    it "should allow a booking the 2nd friday of each month, recurrence ending" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :monthly
      booking.recurrence_days = 0b0100000
      booking.recurrence_nth_of_month = 2
      booking.recurrence_end = Time.local(2024, 4, 1, 0, 0, 0, location: timezone).to_unix
      booking.save!

      start_query = Time.local(2024, 1, 15, 0, 0, 0, location: timezone)
      end_query = Time.local(2024, 5, 20, 0, 0, 0, location: timezone)
      times = booking.calculate_monthly(start_query, end_query).instances
      times.each(&.hour.should(eq(10)))
      times.map(&.day).should eq [9, 8]
    end

    it "checks for monthly bookings where the query is in the past" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :monthly
      booking.recurrence_days = 0b1111111
      booking.recurrence_nth_of_month = 2
      booking.save!

      start_query = Time.local(2019, 1, 15, 0, 0, 0, location: timezone)
      end_query = Time.local(2019, 5, 20, 0, 0, 0, location: timezone)
      times = booking.calculate_monthly(start_query, end_query).instances
      times.size.should eq 0
    end

    it "should allow booking the 2nd last friday of each month" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :monthly
      booking.recurrence_days = 0b0100000
      booking.recurrence_nth_of_month = -2
      booking.save!

      start_query = Time.local(2024, 1, 15, 0, 0, 0, location: timezone)
      end_query = Time.local(2024, 5, 20, 0, 0, 0, location: timezone)
      times = booking.calculate_monthly(start_query, end_query).instances
      times.each(&.hour.should(eq(10)))
      times.map(&.day).should eq [16, 22, 19]
    end

    it "should hydrate a booking instance" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :monthly
      booking.recurrence_days = 0b0100000
      booking.recurrence_nth_of_month = -2
      booking.save!

      other = booking.hydrate_instance(20_i64)
      other.booking_start.should eq 20_i64
      other.instance.should eq 20_i64
      booking.booking_start.should eq start_time.to_unix
      booking.instance.should eq nil
    end

    it "should generate a hydrated bookings responses" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      start_query = Time.local(2020, 1, 5, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)
      bookings = [booking]
      details = Booking.expand_bookings!(start_query, end_query, bookings)
      details.complete.should eq 1
      details.next_idx.should eq 0
      bookings.map(&.starting_tz.day).should eq [10, 11, 12]
    end

    it "should generate a hydrated bookings responses with modified instances" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      start_query = Time.local(2020, 1, 5, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query).instances
      # times.map { |time| time.day }.should eq [11, 12]

      booking_instance = booking.to_instance(times[1].to_unix)
      booking_instance.booking_start += 1.hour.total_seconds.to_i64
      booking_instance.booking_end += 1.hour.total_seconds.to_i64
      booking_instance.save!

      bookings = [booking]
      Booking.expand_bookings!(start_query, end_query, bookings)
      bookings.map(&.starting_tz.day).should eq [10, 11, 12]
      bookings.map(&.starting_tz.hour).should eq [10, 11, 10]

      # should serialize to JSON with the instance attribute
      bookings_json = bookings.map(&.to_json)
      bookings_json.map do |book|
        JSON.parse(book)["instance"].as_i64
      end.should eq bookings.map(&.instance)

      # should de-serialize from JSON with the instance attribute
      bookings_json.map do |book|
        Booking.from_json(book).instance
      end.should eq bookings.map(&.instance)
    end

    it "should generate a hydrated bookings responses with modified instances out of the query range" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      start_query = Time.local(2020, 1, 5, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query).instances
      # times.map { |time| time.day }.should eq [11, 12]

      booking_instance = booking.to_instance(times.last.to_unix)
      booking_instance.booking_start += 25.hour.total_seconds.to_i64
      booking_instance.booking_end += 25.hour.total_seconds.to_i64
      booking_instance.save!

      bookings = [booking]
      Booking.expand_bookings!(start_query, end_query, bookings)
      bookings.map(&.starting_tz.day).should eq [10, 11]
      bookings.map(&.starting_tz.hour).should eq [10, 10]

      # should serialize to JSON with the instance attribute
      bookings_json = bookings.map(&.to_json)
      bookings_json.map do |book|
        JSON.parse(book)["instance"].as_i64
      end.should eq bookings.map(&.instance)

      # should de-serialize from JSON with the instance attribute
      bookings_json.map do |book|
        Booking.from_json(book).instance
      end.should eq bookings.map(&.instance)
    end

    # NOTE:: when modifying a future instance and applying to all
    # we should be ending the old recurring instance and creating a new one
    # so that we preserve the history of past events
    it "should reset modified instances if the parent start time is changed" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      start_query = Time.local(2020, 1, 5, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query).instances
      # times.map { |time| time.day }.should eq [11, 12]

      booking_instance = booking.to_instance(times[1].to_unix)
      booking_instance.booking_start += 1.hour.total_seconds.to_i64
      booking_instance.booking_end += 1.hour.total_seconds.to_i64
      booking_instance.save!

      bookings = [booking]
      Booking.expand_bookings!(start_query, end_query, bookings)
      bookings.map(&.starting_tz.day).should eq [10, 11, 12]
      bookings.map(&.starting_tz.hour).should eq [10, 11, 10]

      booking.booking_start += 2.hours.total_seconds.to_i64
      booking.booking_end += 2.hours.total_seconds.to_i64
      booking.save!

      bookings = [booking]
      Booking.expand_bookings!(start_query, end_query, bookings)
      bookings.map(&.starting_tz.day).should eq [10, 11, 12]
      bookings.map(&.starting_tz.hour).should eq [12, 12, 12]

      BookingInstance.where(id: booking.id.as(Int64)).count.should eq 0
    end

    it "should not save a regular booking that clashes with a recurring booking" do
      tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.tenant_id = tenant_id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      clashing = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: start_time + 24.5.hours,
        ending: end_time + 24.5.hours,
      )
      clashing.timezone = "Europe/Berlin"

      times = booking.calculate_daily(clashing.starting_tz, clashing.ending_tz).instances
      times.size.should eq 1

      clashing.save.should eq false
    end

    it "should not save a recurring booking that clashes with a regular booking" do
      tenant_id = Generator.tenant(domain: "recurrence.dev").id

      clashing = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: start_time + 24.5.hours,
        ending: end_time + 24.5.hours,
      )
      clashing.timezone = "Europe/Berlin"
      clashing.save.should eq true

      booking.tenant_id = tenant_id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save.should eq false
    end

    it "should not save a recurring booking that clashes with a regular booking, rear offset" do
      tenant_id = Generator.tenant(domain: "recurrence.dev").id

      clashing = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: start_time - 0.5.hours,
        ending: end_time - 0.5.hours,
      )
      clashing.timezone = "Europe/Berlin"
      clashing.save.should eq true

      booking.tenant_id = tenant_id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save.should eq false
    end

    it "should not save a recurring booking that clashes with another recurring booking" do
      tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.tenant_id = tenant_id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      clashing = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: start_time - 48.hours,
        ending: end_time - 48.hours,
      )
      clashing.timezone = "Europe/Berlin"
      clashing.recurrence_type = :weekly
      clashing.recurrence_days = 0b1111111
      clashing.save.should eq false
    end

    it "should not save a recurring booking that clashes with a custom recurring instance" do
      tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.tenant_id = tenant_id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      start_query = Time.local(2020, 1, 5, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query).instances
      # times.map { |time| time.day }.should eq [11, 12]

      booking_instance = booking.to_instance(times[1].to_unix)
      booking_instance.booking_start += 2.hour.total_seconds.to_i64
      booking_instance.booking_end += 2.hour.total_seconds.to_i64
      booking_instance.save!
      inst = booking_instance.hydrate_booking

      clashing = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: inst.starting_tz - 48.hours,
        ending: inst.ending_tz - 48.hours,
      )
      clashing.timezone = "Europe/Berlin"
      clashing.recurrence_type = :daily
      clashing.recurrence_days = 0b1111111
      clashing.save.should eq false

      clashing = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: inst.starting_tz - 47.hours,
        ending: inst.ending_tz - 47.hours,
      )
      clashing.timezone = "Europe/Berlin"
      clashing.recurrence_type = :daily
      clashing.recurrence_days = 0b1111111
      clashing.save.should eq true
    end

    it "should not save a regular booking that clashes with a custom recurring instance" do
      tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.tenant_id = tenant_id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      start_query = Time.local(2020, 1, 5, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query).instances
      # times.map { |time| time.day }.should eq [11, 12]

      booking_instance = booking.to_instance(times[1].to_unix)
      booking_instance.booking_start += 2.hour.total_seconds.to_i64
      booking_instance.booking_end += 2.hour.total_seconds.to_i64
      booking_instance.save!
      inst = booking_instance.hydrate_booking

      clashing = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: inst.starting_tz,
        ending: inst.ending_tz,
      )
      clashing.timezone = "Europe/Berlin"
      clashing.save.should eq false

      clashing = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: inst.starting_tz - 1.hour,
        ending: inst.ending_tz - 1.hour,
      )
      clashing.timezone = "Europe/Berlin"
      clashing.save.should eq true
    end

    it "should save a regular booking that clashes with a custom recurring instance that has been checked out" do
      tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.tenant_id = tenant_id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      start_query = Time.local(2020, 1, 5, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query).instances
      # times.map { |time| time.day }.should eq [11, 12]

      booking_instance = booking.to_instance(times[0].to_unix)
      booking_instance.checked_in = false
      booking_instance.checked_out_at = Time.utc.to_unix
      booking_instance.save!
      inst = booking_instance.hydrate_booking

      clashing = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: inst.starting_tz,
        ending: inst.ending_tz,
      )
      clashing.timezone = "Europe/Berlin"
      clashing.clashing_bookings.empty?.should be_true
    end

    it "should should transparently save modified instances" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      start_query = Time.local(2020, 1, 5, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query).instances

      # unmodified bookings
      bookings = [booking]
      Booking.expand_bookings!(start_query, end_query, bookings)
      bookings.map(&.starting_tz.day).should eq [10, 11, 12]
      bookings.map(&.starting_tz.hour).should eq [10, 10, 10]

      # save a booking object
      booking_instance = bookings[1]
      booking_instance.instance.should eq times[1].to_unix
      booking_instance.booking_start += 1.hour.total_seconds.to_i64
      booking_instance.booking_end += 1.hour.total_seconds.to_i64
      booking_instance.save!

      # check if it saved the instance
      bookings = [booking]
      Booking.expand_bookings!(start_query, end_query, bookings)
      bookings.map(&.starting_tz.day).should eq [10, 11, 12]
      bookings.map(&.starting_tz.hour).should eq [10, 11, 10]
    end

    it "should allow modified instances to have an overlapping time" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      start_query = Time.local(2020, 1, 5, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query).instances

      # unmodified bookings
      bookings = [booking]
      Booking.expand_bookings!(start_query, end_query, bookings)
      bookings.map(&.ending_tz.minute).should eq [0, 0, 0]

      # save a booking object
      booking_instance = bookings[1]
      booking_instance.instance.should eq times[1].to_unix
      booking_instance.booking_end -= 30.minutes.total_seconds.to_i64
      booking_instance.save!

      # check if it saved the instance
      bookings = [booking]
      Booking.expand_bookings!(start_query, end_query, bookings)
      bookings.map(&.ending_tz.minute).should eq [0, 30, 0]

      # re-save the instance
      booking_instance = bookings[1]
      booking_instance.instance.should eq times[1].to_unix
      booking_instance.booking_end += 5.minutes.total_seconds.to_i64
      booking_instance.save!

      # check if it saved the instance
      bookings = [booking]
      Booking.expand_bookings!(start_query, end_query, bookings)
      bookings.map(&.ending_tz.minute).should eq [0, 35, 0]
    end

    it "should support limits" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      start_query = Time.local(2020, 1, 15, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 20, 0, 0, 0, location: timezone)
      details = booking.calculate_daily(start_query, end_query, limit: 3)
      details.limit_reached.should eq true
      times = details.instances
      times.each(&.hour.should(eq(10)))
      times.map(&.day).should eq [15, 16, 17]
    end

    it "should hydrate bookings, supporting limits and skips" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      start_query = Time.local(2020, 1, 5, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)
      bookings = [booking]
      details = Booking.expand_bookings!(start_query, end_query, bookings, limit: 1)
      details.complete.should eq 0
      details.next_idx.should eq 1
      bookings.map(&.starting_tz.day).should eq [10]

      start_query = Time.local(2020, 1, 5, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)
      bookings = [booking]
      details = Booking.expand_bookings!(start_query, end_query, bookings, limit: 2, skip: 1)
      details.complete.should eq 1
      details.next_idx.should eq 0
      bookings.map(&.starting_tz.day).should eq [11, 12]
    end

    it "should reject recurring booking that clashes with regular all day or similar booking" do
      tenant_id = Generator.tenant(domain: "recurrence.dev").id

      all_day = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: Time.local(2025, 5, 28, location: timezone),
        ending: Time.local(2025, 5, 28, location: timezone) + 8.hours
      )
      all_day.timezone = "Europe/Berlin"
      all_day.all_day = true
      all_day.save.should eq true

      Booking.find?(all_day.id.not_nil!).should_not be_nil

      recurring_booking = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: Time.local(2025, 5, 24, location: timezone),
        ending: Time.local(2025, 5, 31, location: timezone)
      )
      recurring_booking.tenant_id = tenant_id
      recurring_booking.recurrence_type = :daily
      recurring_booking.recurrence_days = 0b1111111
      recurring_booking.timezone = "Europe/Berlin"
      recurring_booking.save.should eq false
    end

    it "should generate correct number of daily recurrence instances" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.recurrence_interval = 1
      booking.save!

      # Test 5-day period starting from booking date
      today = Time.local(2020, 1, 10, 10, 0, 0, location: timezone)
      query_start = today
      query_end = today + 5.days

      # Should generate one instance per day for 5 days
      details = booking.calculate_daily(query_start, query_end)
      times = details.instances
      times.size.should eq 5

      # Verify consecutive days
      times.each_with_index do |time, index|
        expected_day = today + index.days
        time.day.should eq expected_day.day
        time.hour.should eq 10
      end

      # Test limit functionality
      limited_2 = booking.calculate_daily(query_start, query_end, limit: 2)
      limited_2.instances.size.should eq 2
      limited_2.limit_reached.should be_true

      limited_3 = booking.calculate_daily(query_start, query_end, limit: 3)
      limited_3.instances.size.should eq 3
      limited_3.limit_reached.should be_true
    end

    it "should validate expand_bookings behavior with limits" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.recurrence_interval = 1
      booking.save!

      # Test the specific scenario: original booking + 2 more occurrences
      today = Time.local(2020, 1, 10, 10, 0, 0, location: timezone)
      query_start = today
      query_end = today + 3.days

      # Test with expand_bookings (this is what the UI likely uses)
      bookings = [booking]
      expansion = Booking.expand_bookings!(query_start, query_end, bookings)

      # Should generate 3 bookings total (original + 2 more)
      bookings.size.should eq 3
      expansion.complete.should eq 1
      expansion.next_idx.should eq 0

      # Verify the booking times are correct
      bookings[0].starting_tz.day.should eq 10 # Original
    end

    it "should handle daily recurrence with custom intervals correctly" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111 # All days
      booking.recurrence_interval = 3     # Every 3 days
      booking.save!

      start_query = Time.local(2020, 1, 10, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 25, 0, 0, 0, location: timezone)

      times = booking.calculate_daily(start_query, end_query).instances
      times.map(&.day).should eq [10, 13, 16, 19, 22]
    end

    it "should respect day-of-week restrictions in daily recurrence" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b0100010 # Only Monday and Friday (bits 1 and 5)
      booking.recurrence_interval = 1
      booking.save!

      # Start on a Friday (Jan 10, 2020)
      start_query = Time.local(2020, 1, 10, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 20, 0, 0, 0, location: timezone)

      times = booking.calculate_daily(start_query, end_query).instances
      # Should only include Friday 10th, Monday 13th, Friday 17th
      times.map(&.day).should eq [10, 13, 17]
      times.each { |time| [Time::DayOfWeek::Monday, Time::DayOfWeek::Friday].should contain(time.day_of_week) }
    end

    it "should handle edge case where query starts before booking start" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.recurrence_interval = 2
      booking.save!

      # Query starts before the booking
      start_query = Time.local(2020, 1, 5, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 20, 0, 0, 0, location: timezone)

      times = booking.calculate_daily(start_query, end_query).instances
      # Should start from booking date (Jan 10) and follow interval
      times.map(&.day).should eq [10, 12, 14, 16, 18]
    end

    it "should handle bi-weekly recurrence" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.booking_start = Time.local(2020, 1, 6, 10, 0, 0, location: timezone).to_unix # Monday
      booking.booking_end = (Time.local(2020, 1, 6, 10, 0, 0, location: timezone) + 1.hour).to_unix
      booking.recurrence_type = :weekly
      booking.recurrence_days = 0b0000010 # Monday only
      booking.recurrence_interval = 2     # Every 2 weeks
      booking.save!

      start_query = Time.local(2020, 1, 6, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 3, 1, 0, 0, 0, location: timezone)

      times = booking.calculate_weekly(start_query, end_query).instances
      # Should be every other Monday
      times.map(&.day).should eq [6, 20, 3, 17] # Jan 6, Jan 20, Feb 3, Feb 17
    end

    it "should correctly calculate 2nd Friday of each month" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :monthly
      booking.recurrence_days = 0b0100000 # Friday only
      booking.recurrence_nth_of_month = 2 # 2nd occurrence
      booking.recurrence_interval = 1
      booking.save!

      start_query = Time.local(2020, 1, 1, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 6, 1, 0, 0, 0, location: timezone)

      times = booking.calculate_monthly(start_query, end_query).instances
      # 2nd Friday of each month: Jan 10, Feb 14, Mar 13, Apr 10, May 8
      times.map(&.day).should eq [10, 14, 13, 10, 8]
      times.each { |time| time.day_of_week.should eq Time::DayOfWeek::Friday }
    end

    it "should handle quarterly recurrence (every 3 months)" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :monthly
      booking.recurrence_days = 0b0000010 # Monday only
      booking.recurrence_nth_of_month = 1 # 1st Monday
      booking.recurrence_interval = 3     # Every 3 months
      booking.save!

      start_query = Time.local(2020, 1, 1, 0, 0, 0, location: timezone)
      end_query = Time.local(2021, 1, 1, 0, 0, 0, location: timezone)

      times = booking.calculate_monthly(start_query, end_query).instances
      times.map(&.day).should eq [10, 6, 6, 5]
      times.map(&.month).should eq [1, 4, 7, 10]
    end

    it "should correctly handle monthly recurrence starting mid-year" do
      # Booking starts in June
      june_start = Time.local(2020, 6, 12, 10, 0, 0, location: timezone) # 2nd Friday of June
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.booking_start = june_start.to_unix
      booking.booking_end = (june_start + 1.hour).to_unix
      booking.recurrence_type = :monthly
      booking.recurrence_days = 0b0100000 # Friday only
      booking.recurrence_nth_of_month = 2 # 2nd Friday
      booking.recurrence_interval = 1
      booking.save!

      # Query for rest of the year
      start_query = Time.local(2020, 6, 1, 0, 0, 0, location: timezone)
      end_query = Time.local(2021, 1, 1, 0, 0, 0, location: timezone)

      times = booking.calculate_monthly(start_query, end_query).instances
      times.map(&.day).should eq [12, 10, 14, 11, 9, 13, 11]
      times.map(&.month).should eq [6, 7, 8, 9, 10, 11, 12]
    end

    it "should handle recurrence end date correctly" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.recurrence_interval = 1
      booking.recurrence_end = Time.local(2020, 1, 15, 0, 0, 0, location: timezone).to_unix
      booking.save!

      start_query = Time.local(2020, 1, 10, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 20, 0, 0, 0, location: timezone)

      times = booking.calculate_daily(start_query, end_query).instances
      # Should stop at recurrence_end date
      times.map(&.day).should eq [10, 11, 12, 13, 14]
    end

    it "should handle timezone changes correctly" do
      # Test with different timezone
      ny_timezone = Time::Location.load("America/New_York")
      ny_start = Time.local(2020, 1, 10, 10, 0, 0, location: ny_timezone)

      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.booking_start = ny_start.to_unix
      booking.booking_end = (ny_start + 1.hour).to_unix
      booking.timezone = "America/New_York"
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.recurrence_interval = 1
      booking.save!

      start_query = Time.local(2020, 1, 10, 0, 0, 0, location: ny_timezone)
      end_query = Time.local(2020, 1, 15, 0, 0, 0, location: ny_timezone)

      times = booking.calculate_daily(start_query, end_query).instances
      times.size.should eq 5
      times.each(&.hour.should(eq(10)))
    end

    it "should handle empty recurrence_days gracefully" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b0000000 # No days selected
      booking.recurrence_interval = 1
      booking.save!

      start_query = Time.local(2020, 1, 10, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 15, 0, 0, 0, location: timezone)

      times = booking.calculate_daily(start_query, end_query).instances
      # Should return no occurrences
      times.size.should eq 0
    end

    it "should respect recurrence interval for daily bookings" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.recurrence_interval = 2 # Every 2 days
      booking.save!

      today = Time.local(2020, 1, 10, 10, 0, 0, location: timezone)
      query_start = today
      query_end = today + 10.days

      times = booking.calculate_daily(query_start, query_end).instances

      # Should generate instances every 2 days: 10th, 12th, 14th, 16th, 18th
      times.size.should eq 5

      # Verify the interval is working correctly
      times.each_with_index do |time, index|
        expected_day = 10 + (index * 2)
        time.day.should eq expected_day
        time.hour.should eq 10
      end

      # Verify consecutive instances are 2 days apart
      (1...times.size).each do |i|
        day_diff = times[i].day - times[i - 1].day
        day_diff.should eq 2
      end
    end

    it "should generate correct monthly recurrence on 2nd Friday" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :monthly
      booking.recurrence_days = 0b0100000 # Friday only
      booking.recurrence_nth_of_month = 2 # 2nd Friday
      booking.recurrence_interval = 1
      booking.save!

      query_start = Time.local(2020, 1, 1, 0, 0, 0, location: timezone)
      query_end = Time.local(2020, 6, 30, 0, 0, 0, location: timezone)

      times = booking.calculate_monthly(query_start, query_end).instances

      # Should find 2nd Friday of each month from Jan to June (6 months)
      times.size.should eq 6

      # Verify all are Fridays
      times.each do |time|
        time.day_of_week.should eq Time::DayOfWeek::Friday
      end

      # Verify specific dates for 2nd Friday of each month in 2020
      expected_days = [10, 14, 13, 10, 8, 12] # 2nd Friday of Jan-Jun 2020
      times.each_with_index do |time, index|
        time.day.should eq expected_days[index]
        time.month.should eq index + 1
      end
    end

    it "should handle negative nth_of_month correctly" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :monthly
      booking.recurrence_days = 0b0100000  # Friday only
      booking.recurrence_nth_of_month = -1 # Last Friday
      booking.save!

      start_query = Time.local(2024, 1, 1, 0, 0, 0, location: timezone)
      end_query = Time.local(2024, 3, 31, 0, 0, 0, location: timezone)
      times = booking.calculate_monthly(start_query, end_query).instances

      # Should find last Friday of each month
      times.each do |time|
        time.day_of_week.should eq Time::DayOfWeek::Friday
        # Verify it's the last Friday by checking next Friday is in next month
        next_friday = time + 7.days
        next_friday.month.should_not eq time.month
      end
    end

    it "should handle booking instances that extend beyond query range" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      start_query = Time.local(2020, 1, 10, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 12, 5, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query).instances

      # Create an instance that extends beyond the query range
      booking_instance = booking.to_instance(times[0].to_unix)
      booking_instance.booking_end += 25.hours.total_seconds.to_i64 # Extends to next day
      booking_instance.save!

      bookings = [booking]
      Booking.expand_bookings!(start_query, end_query, bookings)

      # Should handle instances that extend beyond range correctly
      extended_booking = bookings.find { |b| b.instance == times[0].to_unix }
      extended_booking.should_not be_nil
    end

    it "should validate recurrence_days bitmap correctly" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily

      # Test valid bitmap
      booking.recurrence_days = 0b0111110 # Weekdays only
      booking.recurrence_on.size.should eq 5

      # Test all days
      booking.recurrence_days = 0b1111111 # All days
      booking.recurrence_on.size.should eq 7

      # Test single day
      booking.recurrence_days = 0b0000010 # Monday only
      booking.recurrence_on.size.should eq 1
      booking.recurrence_on.should contain(Time::DayOfWeek::Monday)
    end

    it "should handle empty timezone string gracefully" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.timezone = ""

      # Should not crash when calling timezone methods with empty string
      # The .presence method should handle empty strings gracefully
      booking.starting_tz.should be_a(Time)
      booking.ending_tz.should be_a(Time)

      # Should still work with nil timezone
      booking.timezone = nil
      booking.starting_tz.should be_a(Time)
      booking.ending_tz.should be_a(Time)
    end
  end
end
