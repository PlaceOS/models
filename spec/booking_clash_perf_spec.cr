require "./helper"

module PlaceOS::Model
  # Behavioural coverage for the clash-detection performance changes:
  #   #1 skip_clash_check opt-out (and that it is NOT API-settable)
  #   #2 early-exit `limit` on clashing_bookings / clashing?
  #   #4 sweep-line recurring overlap detection
  #   #5 bounded recurring candidate query still finds real clashes
  describe "booking clash detection performance behaviours" do
    timezone = Time::Location.load("Europe/Berlin")
    start_time = Time.local(2020, 1, 10, 10, 0, 0, location: timezone)
    end_time = start_time + 1.hour

    tenant_id = uninitialized Int64

    Spec.before_each do
      Booking.clear
      BookingInstance.clear
      Tenant.clear
    end

    # created inside each example (not the global before_each): another spec
    # file's global before_each may clear the tenants table after ours runs, so
    # make the tenant right before it is needed to stay resilient in a combined
    # suite run.
    new_tenant = -> do
      tenant_id = Generator.tenant(domain: "clashperf.dev").id.as(Int64)
    end

    one_off = ->(asset : String, s : Time, e : Time) do
      b = Generator.booking(tenant_id, asset_id: asset, start: s, ending: e)
      b.timezone = "Europe/Berlin"
      b
    end

    recurring = ->(asset : String, s : Time, e : Time, days : Int32, rec_end : Time) do
      b = Generator.booking(tenant_id, asset_id: asset, start: s, ending: e)
      b.timezone = "Europe/Berlin"
      b.recurrence_type = :daily
      b.recurrence_days = days
      b.recurrence_end = rec_end.to_unix
      b
    end

    describe "#1 skip_clash_check opt-out" do
      it "bypasses the clash validation when set" do
        new_tenant.call
        b1 = one_off.call("desk-1", start_time, end_time)
        b1.save!

        b2 = one_off.call("desk-1", start_time, end_time) # same slot -> would clash
        b2.skip_clash_check = true
        b2.save! # must NOT raise
        Booking.find(b2.id.as(Int64)).asset_id.should eq "desk-1"
      end

      it "still detects the clash by default" do
        new_tenant.call
        b1 = one_off.call("desk-1", start_time, end_time)
        b1.save!
        b2 = one_off.call("desk-1", start_time, end_time)
        expect_raises(PgORM::Error::RecordInvalid, /must not clash/) { b2.save! }
      end

      it "cannot be set from API JSON input" do
        new_tenant.call
        b = one_off.call("desk-1", start_time, end_time)
        b.save!
        payload = JSON.parse(b.to_json).as_h
        payload["skip_clash_check"] = JSON::Any.new(true)
        Booking.from_json(payload.to_json).skip_clash_check.should be_false
      end
    end

    describe "#2 limit / early-exit" do
      it "returns at most `limit` clashes" do
        new_tenant.call
        # two adjacent (non-clashing) bookings that both overlap a third
        a = one_off.call("desk-1", start_time, start_time + 1.hour)
        a.save!
        b = one_off.call("desk-1", start_time + 1.hour, start_time + 2.hours)
        b.save!

        probe = one_off.call("desk-1", start_time + 30.minutes, start_time + 90.minutes)
        probe.clashing_bookings.size.should eq 2
        probe.clashing_bookings(limit: 1).size.should eq 1
        probe.clashing?.should be_true
      end
    end

    describe "#4 sweep-line recurring overlap" do
      rec_end = start_time + 30.days

      it "detects a daily-recurring clash on the same desk" do
        new_tenant.call
        b1 = recurring.call("desk-1", start_time, end_time, 0b1111111, rec_end)
        b1.save!
        b2 = recurring.call("desk-1", start_time + 30.minutes, end_time + 30.minutes, 0b1111111, rec_end)
        b2.clashing_bookings.map(&.id).uniq.should contain b1.id
        b2.clashing?.should be_true
      end

      it "does not flag a recurring booking with a non-overlapping time of day" do
        new_tenant.call
        b1 = recurring.call("desk-1", start_time, end_time, 0b1111111, rec_end)
        b1.save!
        later = start_time + 4.hours
        b2 = recurring.call("desk-1", later, later + 1.hour, 0b1111111, rec_end)
        b2.clashing_bookings.should be_empty
        b2.clashing?.should be_false
      end

      it "detects a clash even when only some weekdays overlap" do
        new_tenant.call
        b1 = recurring.call("desk-1", start_time, end_time, 0b1111111, rec_end) # every day
        b1.save!
        wed_only = 0b0001000 # Wednesday bit only
        b2 = recurring.call("desk-1", start_time + 15.minutes, end_time, wed_only, rec_end)
        b2.clashing?.should be_true
      end

      it "does not flag a different desk" do
        new_tenant.call
        b1 = recurring.call("desk-1", start_time, end_time, 0b1111111, rec_end)
        b1.save!
        b2 = recurring.call("desk-2", start_time + 30.minutes, end_time + 30.minutes, 0b1111111, rec_end)
        b2.clashing?.should be_false
      end
    end

    describe "#5 bounded candidate query still finds real clashes" do
      it "finds an existing series that started in the past and recurs into our window" do
        new_tenant.call
        past_start = start_time - 5.days
        b1 = recurring.call("desk-1", past_start, past_start + 1.hour, 0b1111111, start_time + 30.days)
        b1.save!
        # new recurring booking starting now at the same time of day
        b2 = recurring.call("desk-1", start_time, end_time, 0b1111111, start_time + 10.days)
        b2.clashing?.should be_true
      end

      it "ignores a series whose first occurrence is after our window" do
        new_tenant.call
        future_start = start_time + 20.days
        b1 = recurring.call("desk-1", future_start, future_start + 1.hour, 0b1111111, future_start + 30.days)
        b1.save!
        # short new booking window ending well before b1 begins
        b2 = recurring.call("desk-1", start_time, end_time, 0b1111111, start_time + 3.days)
        b2.clashing?.should be_false
      end
    end
  end
end
