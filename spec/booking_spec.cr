require "./helper"

module PlaceOS::Model
  Spec.before_each do
    Attendee.clear
    Booking.clear
    Guest.clear
  end

  describe Booking do
    it "returns booking with assets", focus: true do
      booking_id = Generator.booking_attendee
      Booking.where(id: booking_id).to_a.size.should eq 1

      query = Booking.where(id: booking_id).join(:left, Attendee, :booking_id).join(:left, Guest, "guests.id = attendees.guest_id")

      booking = query.to_a.first
      booking.attendees.size.should eq 1

      # ensure we didn't need a second query to fill this in
      guests = booking.__guests_rel
      guests.size.should eq 1
      json_booking = JSON.parse(booking.to_json).as_h
      json_booking["guests"].as_a.size.should eq 1
      json_booking["guests"].as_a.first.as_h["checked_in"]?.should be_false

      check_no_guest = Booking.where(id: booking_id).to_a.first
      JSON.parse(check_no_guest.to_json).as_h["guests"]?.should be_nil

      booking.attendees.first.destroy
      sleep 0.1
      query_check = Booking.where(id: booking_id).join(:left, Attendee, :booking_id).join(:left, Guest, "guests.id = attendees.guest_id").to_a.first
      query_check.attendees.size.should eq 0
    end
  end
end
