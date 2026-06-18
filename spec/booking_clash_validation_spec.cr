require "./helper"

module PlaceOS::Model
  # Regression coverage for the clash-detection validation on Booking and
  # BookingInstance. The validation must only fire when the booked slot (time or
  # asset) actually changes, so approving / rejecting / checking in an existing
  # booking is never blocked by a clash it did not introduce.
  #
  # Previously, approving a recurring booking instance raised:
  #   "PlaceOS::Model::BookingInstance has an invalid field.
  #    `booking_start` must not clash with an existing booking"
  describe "booking clash validation" do
    timezone = Time::Location.load("Europe/Berlin")
    start_time = Time.local(2020, 1, 10, 10, 0, 0, location: timezone)
    end_time = start_time + 1.hour
    start_query = Time.local(2020, 1, 5, 5, 0, 0, location: timezone)
    end_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)

    tenant_id = uninitialized Int64

    Spec.before_each do
      Booking.clear
      BookingInstance.clear
      Tenant.clear
    end

    # created per-example: a global `Spec.before_each` in another spec file may
    # clear the tenants table after ours runs, so make the tenant inside the
    # example body (right before it is needed) to stay resilient when suites run
    # together.
    new_tenant = -> do
      tenant_id = Generator.tenant(domain: "recurrence.dev").id.as(Int64)
    end

    make_recurring = ->(asset : String) do
      b = Generator.booking(tenant_id, asset_id: asset, start: start_time, ending: end_time)
      b.timezone = "Europe/Berlin"
      b.recurrence_type = :daily
      b.recurrence_days = 0b1111111
      b
    end

    # mimic the staff-api controller `find_booking` + `set_approver` path
    set_instance_approval = ->(parent_id : Int64, instance_start : Int64, approved : Bool) do
      loaded = Booking.find(parent_id)
      loaded.instance = instance_start
      hydrated = loaded.as_instance.hydrate_booking(loaded)
      if approved
        hydrated.approved = true
        hydrated.approved_at = Time.utc.to_unix
        hydrated.rejected = false
        hydrated.rejected_at = nil
      else
        hydrated.approved = false
        hydrated.approved_at = nil
        hydrated.rejected = true
        hydrated.rejected_at = Time.utc.to_unix
      end
      hydrated.save!
    end

    describe BookingInstance do
      it "approves a recurring instance with no other bookings" do
        new_tenant.call
        b1 = make_recurring.call("desk-1234")
        b1.save!
        inst = b1.calculate_daily(start_query, end_query).instances[1].to_unix

        set_instance_approval.call(b1.id.as(Int64), inst, true)

        reloaded = BookingInstance.where(id: b1.id.as(Int64), instance_start: inst).first
        reloaded.approved.should eq true
      end

      it "re-approves an occurrence after its freed slot was re-booked" do
        new_tenant.call
        b1 = make_recurring.call("desk-1234")
        b1.save!
        inst = b1.calculate_daily(start_query, end_query).instances[1].to_unix # day 11

        # reject the day-11 occurrence, freeing the slot
        set_instance_approval.call(b1.id.as(Int64), inst, false)

        # book the freed slot with a different one-off booking on the same desk
        b2 = Generator.booking(tenant_id, asset_id: "desk-1234", start: Time.unix(inst), ending: Time.unix(inst) + 1.hour)
        b2.timezone = "Europe/Berlin"
        b2.save! # succeeds because the recurring occurrence is rejected

        # re-approve the original occurrence -> must not raise on the unchanged slot
        set_instance_approval.call(b1.id.as(Int64), inst, true)

        reloaded = BookingInstance.where(id: b1.id.as(Int64), instance_start: inst).first
        reloaded.approved.should eq true
        reloaded.rejected.should eq false
      end

      it "still rejects moving an occurrence onto an occupied slot" do
        new_tenant.call
        b1 = make_recurring.call("desk-1234")
        b1.save!
        inst = b1.calculate_daily(start_query, end_query).instances[1].to_unix # day 11 10:00

        # a one-off on the same desk later that day (no clash with the 10:00 slot)
        busy_start = Time.unix(inst) + 4.hours
        b3 = Generator.booking(tenant_id, asset_id: "desk-1234", start: busy_start, ending: busy_start + 1.hour)
        b3.timezone = "Europe/Berlin"
        b3.save!

        # move the day-11 occurrence onto the occupied 14:00 slot -> must still clash
        moved = b1.to_instance(inst)
        moved.booking_start = busy_start.to_unix
        moved.booking_end = (busy_start + 1.hour).to_unix

        expect_raises(PgORM::Error::RecordInvalid, /must not clash/) do
          moved.save!
        end
      end
    end

    describe Booking do
      it "re-approves a booking after its freed slot was re-booked" do
        new_tenant.call
        b1 = Generator.booking(tenant_id, asset_id: "desk-1234", start: start_time, ending: end_time)
        b1.timezone = "Europe/Berlin"
        b1.save!

        # reject it, freeing the slot
        b1.rejected = true
        b1.rejected_at = start_time.to_unix
        b1.save!

        # someone else takes the freed slot
        b2 = Generator.booking(tenant_id, asset_id: "desk-1234", start: start_time, ending: end_time)
        b2.timezone = "Europe/Berlin"
        b2.save!

        # re-approving only touches approval fields (slot unchanged) -> allowed
        b1.approved = true
        b1.approved_at = Time.utc.to_unix
        b1.rejected = false
        b1.rejected_at = nil
        b1.save!

        Booking.find(b1.id.as(Int64)).approved.should eq true
      end

      it "still rejects creating a clashing booking" do
        new_tenant.call
        b1 = Generator.booking(tenant_id, asset_id: "desk-1234", start: start_time, ending: end_time)
        b1.timezone = "Europe/Berlin"
        b1.save!

        b2 = Generator.booking(tenant_id, asset_id: "desk-1234", start: start_time, ending: end_time)
        b2.timezone = "Europe/Berlin"

        expect_raises(PgORM::Error::RecordInvalid, /must not clash/) do
          b2.save!
        end
      end

      it "still rejects moving a booking onto an occupied slot" do
        new_tenant.call
        b1 = Generator.booking(tenant_id, asset_id: "desk-1234", start: start_time, ending: end_time)
        b1.timezone = "Europe/Berlin"
        b1.save!

        later = start_time + 4.hours
        b2 = Generator.booking(tenant_id, asset_id: "desk-1234", start: later, ending: later + 1.hour)
        b2.timezone = "Europe/Berlin"
        b2.save!

        # move b1 onto b2's slot
        b1.booking_start = later.to_unix
        b1.booking_end = (later + 1.hour).to_unix

        expect_raises(PgORM::Error::RecordInvalid, /must not clash/) do
          b1.save!
        end
      end
    end
  end
end
