require "json"
require "./base/model"
require "./booking"

module PlaceOS::Model
  class BookingInstance < ModelWithAutoKey
    table :booking_instances

    alias History = Booking::History

    attribute id : Int64
    # the original starting time of the instance
    attribute instance_start : Int64
    attribute tenant_id : Int64

    # the new start and end times
    attribute booking_start : Int64
    attribute booking_end : Int64

    attribute checked_in : Bool = false
    attribute checked_in_at : Int64?
    attribute checked_out_at : Int64?
    attribute deleted : Bool = false
    attribute deleted_at : Int64?

    attribute extension_data : JSON::Any? = nil
    attribute history : Array(History) = [] of History, converter: PlaceOS::Model::DBArrConverter(PlaceOS::Model::Booking::History)

    # property so we can set this if we've already fetched the parent
    property parent_booking : Booking { Booking.find(self.id) }

    scope :by_tenant do |tenant_id|
      where(tenant_id: tenant_id)
    end

    # returns a booking object that represents this instance
    def hydrate_booking(main : Booking = parent_booking) : Booking
      instance = main.dup
      instance.booking_start = self.booking_start
      instance.booking_end = self.booking_end
      instance.instance = self.instance_start
      instance.checked_in = self.checked_in
      instance.checked_in_at = self.checked_in_at
      instance.checked_out_at = self.checked_out_at
      instance.deleted = self.deleted
      instance.deleted_at = self.deleted_at
      if ext_data = self.extension_data
        instance.extension_data = ext_data
      end
      instance.history = self.history
      instance.created_at = self.created_at
      instance.updated_at = self.updated_at
      instance
    end
  end
end
