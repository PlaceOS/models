require "./helper"

module PlaceOS::Model
  describe Booking, focus: true do
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

    it "should have a booking every day" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      start_query = Time.local(2020, 1, 15, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 20, 0, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query)
      times.each { |time| time.hour.should eq 10 }
      times.map { |time| time.day }.should eq [15, 16, 17, 18, 19]
    end

    it "checks for bookings where the query starts in the past (overlapping)" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      start_query = Time.local(2020, 1, 5, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query)
      times.each { |time| time.hour.should eq 10 }
      times.map { |time| time.day }.should eq [11, 12]
    end

    it "checks for bookings where the query starts in the past (no overlap)" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      start_query = Time.local(2020, 1, 1, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 10, 5, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query)
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
      times = booking.calculate_daily(start_query, end_query)
      times.each { |time| time.hour.should eq 10 }
      times.map { |time| time.day }.should eq [12, 14, 16, 18]

      start_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 20, 5, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query)
      times.each { |time| time.hour.should eq 10 }
      times.map { |time| time.day }.should eq [14, 16, 18]
    end

    it "checks for bookings that should only land on weekdays" do
      # start_query is a wednesday
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b0111110
      booking.save!

      start_query = Time.local(2020, 1, 15, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 20, 0, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query)
      times.each { |time| time.hour.should eq 10 }
      times.map { |time| time.day }.should eq [15, 16, 17]
    end

    it "checks bookings cut off on recurrence end date" do
      booking.tenant_id = Generator.tenant(domain: "recurrence.dev").id
      booking.recurrence_type = :daily
      booking.recurrence_end = Time.local(2020, 1, 17, 0, 0, 0, location: timezone).to_unix
      booking.recurrence_days = 0b0111110
      booking.save!

      start_query = Time.local(2020, 1, 15, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 20, 0, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query)
      times.each { |time| time.hour.should eq 10 }
      times.map { |time| time.day }.should eq [15, 16]
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
      times = booking.calculate_weekly(start_query, end_query)
      times.each { |time| time.hour.should eq 10 }
      times.map { |time| time.day }.should eq [8, 15, 22, 29]

      # should have a booking every week overlap query
      start_query = Time.local(2019, 12, 10, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 2, 1, 0, 0, 0, location: timezone)
      times = booking.calculate_weekly(start_query, end_query)
      times.each { |time| time.hour.should eq 10 }
      times.map { |time| time.day }.should eq [8, 15, 22, 29]
    end
  end
end
