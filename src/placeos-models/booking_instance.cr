require "json"
require "./base/model"
require "./booking"

module PlaceOS::Model
  class BookingInstance < PgORM::Base
    include Neuroplastic

    macro inherited
      Log = ::Log.for(self)
      include OpenAPI::Generator::Serializable::Adapters::ActiveModel
      extend OpenAPI::Generator::Serializable
    end

    include Model::Associations
    include Model::Timestamps

    table :booking_instances

    alias History = Booking::History

    attribute booking_id : Int64
    attribute instance_start : Int64

    attribute booking_start : Int64
    attribute booking_end : Int64

    attribute checked_in : Bool = false
    attribute checked_in_at : Int64?
    attribute checked_out_at : Int64?
    attribute deleted : Bool = false
    attribute deleted_at : Int64?

    attribute extension_data : JSON::Any = JSON::Any.new(Hash(String, JSON::Any).new)
    attribute history : Array(History) = [] of History, converter: PlaceOS::Model::DBArrConverter(PlaceOS::Model::Booking::History)

    # property so we can set this if we've already fetched the parent
    property parent_booking : Booking { Booking.find(self.booking_id) }

    # returns a booking object that represents this instance
    def hydrate_booking(main : Booking = parent_booking) : Booking
    end
  end
end
