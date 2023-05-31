require "json"
require "./base/model"
require "./attendee"
require "./tenant"
require "./utilities/jsonb_query_helper"
require "./email"

module PlaceOS::Model
  class Booking < ModelWithAutoKey
    table :bookings

    record History, state : State, time : Int64, source : String? = nil do
      include JSON::Serializable
    end

    enum State
      Reserved   # Booking starts in the future, no one has checked-in and it hasn't been deleted
      CheckedIn  # Booking is currently active (the wall clock time is between start and end times of the booking) and the user has checked in
      CheckedOut # The user checked out during the start and end times
      NoShow     # It's past the end time of the booking and it was never checked in
      Rejected   # Someone rejected the booking before it started
      Cancelled  # The booking was deleted before the booking start time
      Ended      # The current time is past the end of the booking, the user checked-in but never checked-out
      Unknown
    end

    attribute booking_type : String
    attribute booking_start : Int64
    attribute booking_end : Int64
    attribute timezone : String?
    attribute asset_id : String
    attribute user_id : String?
    attribute user_email : PlaceOS::Model::Email, format: "email", converter: PlaceOS::Model::EmailConverter
    attribute user_name : String
    attribute zones : Array(String) = ->{ [] of String }
    # used to hold information relating to the state of the booking process
    attribute process_state : String?
    attribute last_changed : Int64?
    attribute approved : Bool = false
    attribute approved_at : Int64?
    attribute rejected : Bool = false
    attribute rejected_at : Int64?
    attribute approver_id : String?
    attribute approver_name : String?
    attribute approver_email : String?, format: "email"
    attribute department : String?
    attribute title : String?
    attribute checked_in : Bool = false
    attribute checked_in_at : Int64?
    attribute checked_out_at : Int64?
    attribute description : String?
    attribute deleted : Bool = false
    attribute deleted_at : Int64?
    attribute booked_by_email : PlaceOS::Model::Email, format: "email", converter: PlaceOS::Model::EmailConverter
    attribute booked_by_name : String
    # if we want to record the system that performed the bookings
    # (kiosk, mobile, swipe etc)
    attribute booked_from : String?
    attribute extension_data : JSON::Any = JSON::Any.new(Hash(String, JSON::Any).new)
    attribute history : Array(History) = [] of History, converter: PlaceOS::Model::DBArrConverter(PlaceOS::Model::Booking::History)

    attribute email_digest : String?, ignore_deserialize: true
    attribute booked_by_id : String, ignore_deserialize: true
    attribute booked_by_email_digest : String?, ignore_deserialize: true
    attribute created : Int64?, ignore_deserialize: true

    attribute parent_id : Int64?
    attribute event_id : Int64?, description: "provided if this booking is associated with a calendar event"

    @[JSON::Field(ignore: true)]
    property render_event : Bool = true

    @[JSON::Field(key: "linked_event", ignore_deserialize: true)]
    getter(linked_event : EventMetadata?) { get_event_metadata }

    @[JSON::Field(key: "linked_bookings", ignore_deserialize: true)]
    getter(children : Array(Booking)?) { get_children }

    @[JSON::Field(key: "attendees", ignore_serialize: true)]
    property req_attendees : Array(PlaceCalendar::Event::Attendee)? = nil

    @[JSON::Field(ignore_deserialize: true)]
    getter(current_state : State) { booking_current_state }

    @[JSON::Field(key: "attendees", ignore_deserialize: true)]
    getter(resp_attendees : Array(Attendee)?) { attendees.try &.to_a }

    attribute utm_source : String? = nil, persistence: false

    belongs_to Tenant, pk_type: Int64

    has_many(
      child_class: Attendee,
      collection_name: "attendees",
      foreign_key: "booking_id",
      dependent: :destroy
    )

    before_create :set_created

    validate :booking_end, "must be after booking_start", ->(this : self) { this.booking_end > this.booking_start }

    before_save do
      @user_id ||= booked_by_id
      @user_email ||= booked_by_email
      @user_name ||= booked_by_name
      @email_digest ||= user_email.digest
      @booked_by_email_digest = booked_by_email.digest
      @booked_from ||= utm_source
      @history = current_history
      Log.error { {
        message: "History contains more than 3 events.",
        id:      id,
      } } if history.size > 3
      survey_trigger
    end

    def survey_trigger
      return unless history_changed?
      state = history.last.state.to_s.upcase

      query = Survey.select("id").where(trigger: state)
      if (zone_list = zones) && !zone_list.empty?
        query = query.where(zone_id: zone_list, building_id: zone_list)
      end

      email = extension_data ? extension_data["host_override"]?.try &.to_s || user_email.to_s : user_email.to_s

      surveys = query.to_a
      surveys.each do |survey|
        Survey::Invitation.create!(
          survey_id: survey.id,
          email: email,
        )
      end
    end

    def current_history : Array(History)
      state = booking_current_state
      history.dup.tap do |booking_history|
        if booking_history.empty? || booking_history.last.state != state
          booking_history << History.new(state, Time.local.to_unix, @utm_source) unless state.unknown?
          @history_changed = true
        end
      end
    end

    def set_created
      self.last_changed = self.created = Time.utc.to_unix
    end

    def change_extension_data(data : JSON::Any)
      @extension_data = data
      @extension_data_changed = true
    end

    scope :by_tenant do |tenant_id|
      where(tenant_id: tenant_id)
    end

    scope :by_user_id do |user_id|
      user_id ? where(user_id: user_id) : self
    end

    scope :by_user_or_email do |user_id_value, user_email_value, include_booked_by|
      # TODO: Construct `user_or_email` query correctly
      booked_by = include_booked_by ? %( OR "booked_by_id" = '#{user_id_value}') : ""
      user_id_value = user_id_value.try &.gsub(/[\'\"\)\(\\\/\$\?\;\:\<\>\+\=\*\&\^\#\!\`\%\}\{\[\]]/, "")
      user_email_value = user_email_value.try &.gsub(/[\'\"\)\(\\\/\$\?\;\:\<\>\=\*\&\^\!\`\%\}\{\[\]]/, "")

      user_email_digest = PlaceOS::Model::Email.new(user_email_value.to_s).digest if user_email_value

      if user_id_value && user_email_digest
        where("user_id = ? OR email_digest = ? #{booked_by}", user_id_value, user_email_digest)
      elsif user_id_value
        where("user_id = ? #{booked_by}", user_id_value)
      elsif user_email_digest
        booked_by = include_booked_by ? %( OR "booked_by_email_digest" = '#{user_email_digest}') : ""
        where("email_digest = ? #{booked_by}", user_email_digest)
      else
        self
      end
    end

    scope :is_extension_data do |value|
      if value
        parse = value.delete &.in?('{', '}')
        array = parse.split(",")
        query = self
        array.each do |entry|
          split_entry = entry.split(":")
          query = query.where(sql: "extension_data @> '#{PlaceOS::Model::JSONBQuery.to_query(split_entry[0], split_entry[1])}'")
        end
        query
      else
        self
      end
    end

    scope :is_state do |state|
      state ? where(process_state: state) : self
    end

    scope :is_created_before do |time|
      time ? where("last_changed < ?", time.not_nil!.to_i64) : self
    end

    scope :is_created_after do |time|
      time ? where("last_changed > ?", time.not_nil!.to_i64) : self
    end

    scope :is_booking_type do |booking_type|
      booking_type ? where(booking_type: booking_type) : self
    end

    def self.booked_between(tenant_id, period_start, period_end)
      find_all_by_sql(<<-SQL, tenant_id, period_start, period_end)
       SELECT b.* from "bookings" b inner join "attendees" a on a.booking_id = b.id where b.tenant_id = $1 AND b.booking_start >= $2 AND b.booking_end <= $3
      SQL
    end

    TRUTHY = {true, "true"}

    scope :is_approved do |value|
      if !value.nil?
        check = value.in?({true, "true"})
        where(approved: check)
      else
        self
      end
    end

    scope :is_rejected do |value|
      if !value.nil?
        check = value.in?({true, "true"})
        where(rejected: check)
      else
        self
      end
    end

    scope :is_checked_in do |value|
      if !value.nil?
        check = value.in?({true, "true"})
        where(checked_in: check)
      else
        self
      end
    end

    scope :is_department do |value|
      if value
        where(department: value)
      else
        self
      end
    end

    # Bookings have the zones in an array.
    #
    # In case of multiple zones as input,
    # we return all bookings that have
    # any of the input zones in their zones array
    scope :by_zones do |zones|
      return self if zones.empty?

      # https://www.postgresql.org/docs/9.1/arrays.html#ARRAYS-SEARCHING
      sql = zones.join(" OR ") do |zone|
        zone = zone.gsub(/[\'\"\)\(\\\/\$\?\;\:\<\>\.\+\=\*\&\^\#\!\`\%\}\{\[\]]/, "")
        "( '#{zone}' = ANY (zones) )"
      end

      where("( #{sql} OR 0=?)", 1)
    end

    # Booking ends in the future, no one has checked-in and it hasn't been deleted
    protected def is_reserved?(current_time : Int64 = Time.local.to_unix)
      booking_end > current_time &&
        !checked_in &&
        checked_in_at.nil? &&
        deleted_at.nil? &&
        rejected_at.nil? &&
        checked_out_at.nil?
    end

    # Booking ends in the future, the user has checked in and it is not cancelled
    protected def is_checked_in?(current_time : Int64 = Time.local.to_unix)
      checked_in_at &&
        checked_in &&
        checked_out_at.nil? &&
        booking_end > current_time &&
        !is_cancelled?
    end

    # The user checked out before the end time
    protected def is_checked_out?
      (co_at = checked_out_at) &&
        booking_end >= co_at
    end

    # It's past the end time of the booking and it was never checked in
    # or the booking was deleted between the start and end time and it was never checked in
    protected def is_no_show?(current_time : Int64 = Time.local.to_unix)
      !checked_in_at &&
        !is_cancelled? &&
        (booking_end < current_time ||
          ((del_at = deleted_at) &&
            booking_end >= del_at))
    end

    # Someone rejected the booking before it started
    protected def is_rejected?
      (r_at = rejected_at) &&
        booking_start > r_at
    end

    # The booking was deleted before the booking start time
    # or before the booking end time if checked in
    protected def is_cancelled?
      (del_at = deleted_at) &&
        (booking_start > del_at ||
          (booking_end > del_at && checked_in))
    end

    # The current time is past the end of the booking, the user checked-in but never checked-out
    protected def is_ended?(current_time : Int64 = Time.local.to_unix)
      !checked_out_at &&
        checked_in_at &&
        booking_end < current_time
    end

    def booking_current_state : State
      current_time = Time.local.to_unix

      case self
      when .is_reserved?(current_time)   then State::Reserved
      when .is_checked_in?(current_time) then State::CheckedIn
      when .is_checked_out?              then State::CheckedOut
      when .is_no_show?(current_time)    then State::NoShow
      when .is_rejected?                 then State::Rejected
      when .is_cancelled?                then State::Cancelled
      when .is_ended?                    then State::Ended
      else
        Log.error { {
          message:        "Booking is in an Unknown state.",
          id:             id,
          current_time:   current_time,
          booking_start:  booking_start,
          booking_end:    booking_end,
          rejected_at:    rejected_at,
          checked_in_at:  checked_in_at,
          checked_out_at: checked_out_at,
          deleted_at:     deleted_at,
        } }
        State::Unknown
      end
    end

    def clashing?
      starting = self.booking_start
      ending = self.booking_end

      # gets all the clashing bookings
      query = Booking
        .by_tenant(tenant_id)
        .where(
          "booking_start < ? AND booking_end > ? AND booking_type = ? AND asset_id = ? AND rejected <> TRUE AND deleted <> TRUE AND checked_out_at IS NULL",
          ending, starting, booking_type, asset_id
        )
      query = query.where("id != ?", id) unless id.nil?
      query.count > 0
    end

    def as_h(include_attendees : Bool = true)
      @resp_attendees = include_attendees ? attendees.to_a : nil
      self
    end

    def to_json(json : ::JSON::Builder)
      @current_state = booking_current_state
      @children = get_children
      if render_event && (meta = get_event_metadata)
        meta.ext_data = nil
        @linked_event = meta
      else
        @linked_event = nil
      end
      super
    end

    # ===
    # Child-parent relationship
    # ===

    def parent?
      parent_id.nil?
    end

    before_update do
      if parent?
        if booking_start_changed? || booking_end_changed?
          Booking.where(parent_id: id).update_all({:booking_start => booking_start, :booking_end => booking_end})
        elsif deleted_changed? || deleted_at_changed?
          Booking.where(parent_id: id).update_all({:deleted => deleted, :deleted_at => deleted_at})
        end
      end
    end

    private def get_children
      return nil unless parent?
      Booking.where(parent_id: id).to_a
    end

    # ===
    # booking to event relationship
    # ===

    def linked?
      event_id.nil?
    end

    before_update do
      if linked?
        if booking_start_changed? || booking_end_changed?
          meta = linked_event.not_nil!
          self.booking_start = meta.event_start
          self.booking_end = meta.event_end
        end
      end
    end

    private def get_event_metadata
      if meta_id = self.event_id
        EventMetadata.find?(meta_id)
      end
    end
  end
end
