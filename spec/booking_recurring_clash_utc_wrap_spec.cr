require "./helper"

module PlaceOS::Model
  # Reproduces the production duplicate-booking bug where two *recurring*
  # bookings end up on the same asset for the same time period.
  #
  # Root cause: `bookings.starting_time` / `bookings.ending_time` are generated
  # columns holding the **UTC** time-of-day of booking_start / booking_end:
  #
  #   starting_time = (TO_TIMESTAMP(booking_start) AT TIME ZONE 'UTC')::TIME
  #   ending_time   = (TO_TIMESTAMP(booking_end)   AT TIME ZONE 'UTC')::TIME
  #
  # `Booking#recurring_clash_check` narrows the candidate set with the time-of-day
  # overlap predicate `starting_time < end_time AND ending_time > start_time`.
  # That interval-overlap test is only valid when neither stored window wraps
  # past midnight. An all-day booking in a timezone *east* of UTC (e.g.
  # Australia/Perth, UTC+8) wraps UTC midnight: its UTC window is 16:00 -> 15:59,
  # i.e. starting_time (16:00) > ending_time (15:59). Such an existing booking is
  # silently excluded from the candidate set, so the new booking's clash is never
  # detected and a duplicate is created.
  #
  # Prod example: desk "desk.4-SE-076", tenant 2, Australia/Perth, two daily
  # recurring all-day bookings (ids 4756 then 6503) overlapping the same day.
  describe "recurring clash detection across a UTC-midnight wrap" do
    perth = "Australia/Perth" # UTC+8, no DST
    timezone = Time::Location.load(perth)

    tenant_id = uninitialized Int64

    Spec.before_each do
      Booking.clear
      BookingInstance.clear
      Tenant.clear
      tenant_id = Generator.tenant(domain: "recurrence.dev").id.as(Int64)
    end

    # a daily-recurring booking with an explicit local start/end-of-day window
    make_recurring = ->(asset : String, start : Time, ending : Time) do
      b = Generator.booking(tenant_id, asset_id: asset, start: start, ending: ending, booking_type: "desk")
      b.timezone = perth
      b.recurrence_type = :daily
      b.recurrence_days = 0b1111111
      b.recurrence_end = (start + 7.days).to_unix
      b.all_day = true
      b
    end

    it "detects a clash between two all-day recurring bookings (UTC wrap) -- prod repro" do
      asset = "desk.4-SE-076"

      # b1: all-day booking, Perth local 00:00 -> 23:59. In UTC this is
      # 16:00 (prev day) -> 15:59, so its generated time-of-day window WRAPS.
      b1_start = Time.local(2026, 6, 25, 0, 0, 0, location: timezone)
      b1_end = Time.local(2026, 6, 25, 23, 59, 0, location: timezone)
      b1 = make_recurring.call(asset, b1_start, b1_end)
      b1.save!

      # sanity: b1's UTC time-of-day really does wrap (start-of-day > end-of-day),
      # exactly what the generated starting_time/ending_time columns store.
      utc_tod = ->(unix : Int64) { Time.unix(unix).to_utc.to_s("%H:%M:%S") }
      (utc_tod.call(b1.booking_start) > utc_tod.call(b1.booking_end)).should be_true

      # b2: same desk, overlapping the same Perth day (08:10 -> 23:59). In UTC
      # this is 00:10 -> 15:59 -- it does NOT wrap, so recurring_clash_check uses
      # the narrow time-of-day filter and drops b1 from the candidate set.
      b2_start = Time.local(2026, 6, 25, 8, 10, 0, location: timezone)
      b2_end = Time.local(2026, 6, 25, 23, 59, 0, location: timezone)
      b2 = make_recurring.call(asset, b2_start, b2_end)

      # the two bookings genuinely overlap on the same asset -> this MUST clash.
      b2.clashing_bookings.map(&.id).should contain b1.id
      expect_raises(PgORM::Error::RecordInvalid, /must not clash/) do
        b2.save!
      end
    end

    it "control: detects the clash when neither window wraps UTC midnight" do
      asset = "desk.control"

      # midday Perth window (10:00 -> 12:00 = UTC 02:00 -> 04:00), no wrap.
      b1_start = Time.local(2026, 6, 25, 10, 0, 0, location: timezone)
      b1_end = Time.local(2026, 6, 25, 12, 0, 0, location: timezone)
      b1 = make_recurring.call(asset, b1_start, b1_end)
      b1.save!

      utc_tod = ->(unix : Int64) { Time.unix(unix).to_utc.to_s("%H:%M:%S") }
      (utc_tod.call(b1.booking_start) < utc_tod.call(b1.booking_end)).should be_true # no wrap

      # overlapping midday window on the same desk
      b2_start = Time.local(2026, 6, 25, 11, 0, 0, location: timezone)
      b2_end = Time.local(2026, 6, 25, 13, 0, 0, location: timezone)
      b2 = make_recurring.call(asset, b2_start, b2_end)

      b2.clashing_bookings.map(&.id).should contain b1.id
      expect_raises(PgORM::Error::RecordInvalid, /must not clash/) do
        b2.save!
      end
    end
  end
end
