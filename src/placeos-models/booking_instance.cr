require "json"
require "./base/model"
require "./booking"

module PlaceOS::Model
  class BookingInstance < ModelWithAutoKey
    table :booking_instances

    alias History = Booking::History

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

    attribute process_state : String?, sanitize: :text
    attribute extension_data : JSON::Any? = nil, sanitize: :common
    attribute history : Array(History) = [] of History, converter: PlaceOS::Model::DBArrConverter(PlaceOS::Model::Booking::History)

    # custom approval state, nil fields inherit from the parent booking.
    # if either approved or rejected is set, all the approval fields are
    # considered overridden as a group (see #hydrate_booking)
    attribute approved : Bool? = nil
    attribute approved_at : Int64?
    attribute rejected : Bool? = nil
    attribute rejected_at : Int64?
    attribute approver_id : String?
    attribute approver_name : String?, sanitize: :text
    attribute approver_email : String?, format: "email"

    # custom asset allocation, nil inherits the parent booking assets
    attribute asset_id : String?
    attribute asset_ids : Array(String)? = nil, converter: PlaceOS::Model::DBNilTextArrConverter

    # property so we can set this if we've already fetched the parent
    property parent_booking : Booking { Booking.find(self.id) }

    scope :by_tenant do |tenant_id|
      where(tenant_id: tenant_id)
    end

    def asset_ids=(vals : Array(String)?)
      @asset_ids = vals
      @asset_ids_changed = true
    end

    # keep the custom asset_id and asset_ids in sync, mirroring
    # Booking#update_assets but with nil meaning inherit from the parent
    def update_assets
      ids = @asset_ids

      # an explicitly cleared or empty list removes the override entirely
      if (ids && ids.empty?) || (ids.nil? && @asset_ids_changed)
        @asset_ids = nil
        self.asset_id = nil
        return
      end

      if aid = @asset_id
        if ids.nil?
          self.asset_ids = [aid]
          return
        elsif ids.size == 1 && !@asset_ids_changed && @asset_id_changed
          ids[0] = aid
          @asset_ids_changed = true
        end
      end

      if ids = @asset_ids
        self.asset_id = ids.first
      end
    end

    before_save :update_assets

    def unique_ids?
      update_assets
      ids = self.asset_ids
      ids.nil? || ids.uniq.size == ids.size
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
      instance.process_state = self.process_state
      if ext_data = self.extension_data
        instance.extension_data = ext_data
      end
      instance.history = self.history

      # apply any custom approval state as a group so we don't mix the
      # parent's approver details with the instance's approval state
      if !self.approved.nil? || !self.rejected.nil?
        instance.approved = self.approved || false
        instance.approved_at = self.approved_at
        instance.rejected = self.rejected || false
        instance.rejected_at = self.rejected_at
        instance.approver_id = self.approver_id
        instance.approver_name = self.approver_name
        instance.approver_email = self.approver_email
      end

      # apply any custom asset allocation
      if ids = self.asset_ids
        unless ids.empty?
          instance.asset_ids = ids.dup
          instance.asset_id = self.asset_id || ids.first
        end
      elsif aid = self.asset_id
        instance.asset_id = aid
        instance.asset_ids = [aid]
      end

      # we'll use the parent's created at
      # instance.created_at = self.created_at
      instance.updated_at = self.updated_at
      instance
    end

    validate :booking_start, "must not clash with an existing booking", ->(this : self) { !this.hydrate_booking.clashing? }
    validate :asset_ids, "must be unique", ->(this : self) { this.unique_ids? }
  end
end
