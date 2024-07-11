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
  end
end
