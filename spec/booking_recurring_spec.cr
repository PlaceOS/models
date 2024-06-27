require "./helper"

module PlaceOS::Model
  describe Booking do
    Spec.before_each do
      Booking.clear
    end

    it "generates correct times for daily recurring bookings", focus: true do
      timezone = Time::Location.load("Europe/Berlin")
      start_time = Time.local(2020, 1, 10, 10, 0, 0, location: timezone)
      end_time = start_time + 1.hour
      tenant_id = Generator.tenant.id

      booking = Generator.booking(
        tenant_id,
        asset_id: "desk-1234",
        start: start_time,
        ending: end_time
      )
      booking.timezone = "Europe/Berlin"
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.save!

      # should have a booking every day
      start_query = Time.local(2020, 1, 15, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 20, 0, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query)
      times.size.should eq 5
      times.each { |time| time.hour.should eq 10 }
      times.map { |time| time.day }.should eq [15, 16, 17, 18, 19]

      # check for bookings where the query starts in the past (overlapping)
      start_query = Time.local(2020, 1, 5, 5, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query)
      times.size.should eq 2
      times.each { |time| time.hour.should eq 10 }
      times.map { |time| time.day }.should eq [11, 12]

      # start_query is a wednesday
      booking.recurrence_days = 0b0111110
      booking.save!
      start_query = Time.local(2020, 1, 15, 0, 0, 0, location: timezone)
      end_query = Time.local(2020, 1, 20, 0, 0, 0, location: timezone)
      times = booking.calculate_daily(start_query, end_query)
      times.size.should eq 3
      times.each { |time| time.hour.should eq 10 }
      times.map { |time| time.day }.should eq [15, 16, 17]

      # cut off on recurrence end date
      booking.recurrence_end = Time.local(2020, 1, 17, 0, 0, 0, location: timezone).to_unix
      booking.recurrence_days = 0b0111110
      booking.save!
      times = booking.calculate_daily(start_query, end_query)
      times.size.should eq 2
      times.each { |time| time.hour.should eq 10 }
      times.map { |time| time.day }.should eq [15, 16]
    end
  end
end
