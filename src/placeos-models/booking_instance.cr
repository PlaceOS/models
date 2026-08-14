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

    # transient, mirrors `Booking#utm_source` -- recorded against the history entry
    # of the transition it caused, never persisted as a column of its own
    attribute utm_source : String? = nil, persistence: false

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
    before_save :update_history

    # An occurrence keeps its own history: `Booking#save!` delegates to
    # `as_instance.save!`, so the parent's `before_save` (and the `current_history`
    # it builds) never runs for an instance. Without this the occurrence records no
    # transitions at all and the `utm_source` behind them is lost.
    #
    # Mirrors `Booking#current_history`. State comes from the hydrated booking --
    # that is exactly what the API presents for this occurrence, so its state is the
    # one the history should record, and it avoids duplicating the state machine.
    def current_history(state : Booking::State) : Array(History)
      history.dup.tap do |instance_history|
        if instance_history.empty? || instance_history.last.state != state
          instance_history << History.new(state, Time.local.to_unix, @utm_source) unless state.unknown?
          @history_changed = true
        end
      end
    end

    protected def update_history
      hydrated = hydrate_booking
      state = hydrated.booking_current_state

      previous = history
      updated = current_history(state)
      @history = updated

      # only on an actual transition, matching `Booking#survey_trigger`. Compare
      # lengths rather than reading `@history_changed` so we don't confuse the
      # ORM's dirty tracking with "did we just append an entry".
      hydrated.trigger_survey_invitations(state) if updated.size > previous.size
    end

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
      # A non-empty extension data object is a complete snapshot for this
      # occurrence and replaces the parent booking's extension data wholesale.
      # Nil, JSON null, and an empty object mean there is no instance snapshot,
      # so the occurrence continues to inherit from the parent booking.
      if (ext_data = self.extension_data) && (snapshot = ext_data.as_h?) && !snapshot.empty?
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

    # transient flag (never (de)serialised, so API clients cannot set it): set by
    # `Booking#as_instance` when the caller has already run an explicit clash
    # check, so save! does not redundantly re-run it.
    @[JSON::Field(ignore: true)]
    @[YAML::Field(ignore: true)]
    property skip_clash_check : Bool = false

    # the clash validation only needs to run when the booked slot itself (time
    # or asset) changes. approving, rejecting or checking in an existing instance
    # must not be blocked by a clash it did not introduce.
    def slot_changed? : Bool
      booking_start_changed? || booking_end_changed? || asset_id_changed? || asset_ids_changed?
    end

    validate :booking_start, "must not clash with an existing booking", ->(this : self) { this.skip_clash_check || !this.slot_changed? || !this.hydrate_booking.clashing? }
    validate :asset_ids, "must be unique", ->(this : self) { this.unique_ids? }
    validate :extension_data, "must be a JSON object", ->(this : self) do
      data = this.extension_data
      data.nil? || data.raw.nil? || !data.as_h?.nil?
    end
  end
end
