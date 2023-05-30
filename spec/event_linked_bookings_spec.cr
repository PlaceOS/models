require "./helper"

module PlaceOS::Model
  describe Booking do
    describe "event metadata linked bookings" do
      it "creates a booking linked to event metadata" do
        tenant = get_tenant
        event_start = 5.minutes.from_now
        event_end = 10.minutes.from_now
        asset_id = "chair"

        event = Generator.event_metadata(tenant.id, event_start, event_end)
        event.save!
        booking = Generator.booking(tenant.id, asset_id, event_start, event_end, event_id: event.id)
        booking.save!

        # ensure the linking is working
        event.bookings.first?.try(&.id).should eq booking.id

        # try changing the event timing and check the booking updated
        event_start = 30.minutes.from_now.to_unix
        event_end = 40.minutes.from_now.to_unix
        event.event_start = event_start
        event.event_end = event_end
        event.save

        booking.reload!
        booking.booking_start.should eq event_start
        booking.event_end.should eq event_end

        # create a clashing booking in the future and
        # check this booking is rejected
        event_start = 60.minutes.from_now.to_unix
        event_end = 70.minutes.from_now.to_unix
        new_booking = Generator.booking(tenant.id, asset_id, event_start, event_end)
        new_booking.save!

        event.event_start = event_start
        event.event_end = event_end
        event.save

        # check that the old booking is now rejected
        booking.reload!
        booking.booking_start.should eq event_start
        booking.event_end.should eq event_end
        booking.rejected.should eq true
      end
    end
  end
end
