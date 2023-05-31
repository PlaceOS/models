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
        booking.booking_end.should eq event_end

        # create a clashing booking in the future and
        # check this booking is rejected
        event_start = 60.minutes.from_now
        event_end = 70.minutes.from_now
        new_booking = Generator.booking(tenant.id, asset_id, event_start, event_end)
        new_booking.save!

        event.event_start = event_start.to_unix
        event.event_end = event_end.to_unix
        event.save

        # check that the old booking is now rejected
        booking.reload!
        booking.booking_start.should eq event_start.to_unix
        booking.booking_end.should eq event_end.to_unix
        booking.rejected.should eq true
      end

      it "should reject a booking if the event is cancelled" do
        tenant = get_tenant
        event_start = 5.minutes.from_now
        event_end = 10.minutes.from_now
        asset_id = "tablet"

        event = Generator.event_metadata(tenant.id, event_start, event_end)
        event.save!
        booking = Generator.booking(tenant.id, asset_id, event_start, event_end, event_id: event.id)
        booking.save!

        # ensure the linking is working
        event.bookings.first?.try(&.id).should eq booking.id

        # check that bookings reject when a meeting is cancelled
        event.cancelled = true
        event.save
        booking.reload!
        booking.rejected.should eq true

        # check bookings are deleted if metadata is destroyed
        event.destroy
        expect_raises(PgORM::Error::RecordNotFound) do
          Booking.find booking.id
        end
      end

      it "should render linked data" do
        tenant = get_tenant
        event_start = 5.minutes.from_now
        event_end = 10.minutes.from_now
        asset_id = "tablet"

        event = Generator.event_metadata(tenant.id, event_start, event_end)
        event.set_ext_data JSON.parse(%({"secret": true}))
        event.save!
        booking = Generator.booking(tenant.id, asset_id, event_start, event_end, event_id: event.id)
        booking.save!

        # ensure the linking is working
        event.bookings.first?.try(&.id).should eq booking.id

        # check that bookings render the linked event metadata
        booking.reload!
        event.ext_data = nil
        JSON.parse(booking.to_json)["linked_event"].should eq JSON.parse(event.to_json)

        # check the event renders the bookings
        event.reload!
        booking.render_event = false
        JSON.parse(event.to_json)["linked_bookings"].should eq [JSON.parse(booking.to_json)]
      end
    end
  end
end
