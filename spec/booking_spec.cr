require "./helper"

module PlaceOS::Model
  Spec.before_each do
    Attendee.clear
    Booking.clear
    Guest.clear
  end

  describe Booking do
    it "returns booking with assets" do
      booking_id = Generator.booking_attendee
      booking = Booking.where(id: booking_id).join(Attendee, :booking_id).join(Guest, "guests.id = attendees.guest_id").to_a.first
      guests = booking.@__guests_rel.as(Array(Guest))
      guests.size.should eq 1
    end
  end
end
