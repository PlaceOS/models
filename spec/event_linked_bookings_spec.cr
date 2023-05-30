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

        event.bookings.first?.try(&.id).should eq booking.id
      end
    end
  end
end
