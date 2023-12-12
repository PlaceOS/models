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
      Booking.where(id: booking_id).to_a.size.should eq 1

      query = Booking.where(id: booking_id).join(Attendee, :booking_id).join(Guest, "guests.id = attendees.guest_id")
      puts "\n\n\nSQL: #{query.to_sql}\n\n\n"

      booking = query.to_a.first
      guests = booking.@__guests_rel.as(Array(Guest))
      guests.size.should eq 1
    end
  end
end
