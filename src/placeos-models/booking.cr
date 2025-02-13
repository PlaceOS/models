require "set"
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

    enum Permission
      PRIVATE # Default, attendees must be invited
      OPEN    # Users in the same tenant can join
      PUBLIC  # Open for everyone to join
    end

    enum Recurrence
      NONE
      DAILY
      WEEKLY
      MONTHLY
    end

    enum Induction
      TENTATIVE
      ACCEPTED
      DECLINED
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

    attribute instance : Int64? = nil, persistence: false, show: true, description: "provided when this booking is an instance of recurring booking"

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
    attribute asset_ids : Array(String) = [] of String

    attribute images : Array(String) = [] of String

    attribute induction : Induction = Induction::TENTATIVE, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::Booking::Induction),
      description: "The induction status of the booking. Defaults to TENTATIVE."

    attribute permission : Permission = Permission::PRIVATE, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::Booking::Permission),
      description: "The permission level for the booking. Defaults to private. If set to private, attendees must be invited.If set to open, users in the same tenant can join. If set to public, the booking is open for everyone to join."

    attribute recurrence_type : Recurrence = Recurrence::NONE, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::Booking::Recurrence),
      description: "Is this a recurring booking. This field defines the type of recurrence"

    attribute recurrence_days : Int32 = 0b0111110, description: "a bitmap of valid days of the week for booking recurrences to land on, defaults to weekdays"

    attribute recurrence_nth_of_month : Int32 = 1, description: "which day index should a monthly recurrence land on. 1st Monday, 2nd Monday (used in conjunction with the days bitmap). -1 == last Monday, -2 Second last Monday etc"

    attribute recurrence_interval : Int32 = 1, description: "1 == every occurrence, 2 == every second occurrence, etc"

    attribute recurrence_end : Int64? = nil, description: "an optional end date for booking recurrences"

    belongs_to Tenant, pk_type: Int64

    has_many(
      child_class: Attendee,
      collection_name: "attendees",
      foreign_key: "booking_id",
      dependent: :destroy
    )

    # NOTE:: not to be used directly, only here for caching
    has_many(
      child_class: Guest,
      collection_name: "guests",
      foreign_key: "id",
      serialize: true
    )

    def booking_instances
      BookingInstance.where(id: self.id)
    end

    def starting_tz : Time
      time = Time.unix(self.booking_start)
      if tz = self.timezone
        time = time.in(Time::Location.load tz)
      end
      time
    end

    def ending_tz : Time
      time = Time.unix(self.booking_end)
      if tz = self.timezone
        time = time.in(Time::Location.load tz)
      end
      time
    end

    macro finished
      def invoke_props
        previous_def
        if (guests_rel = @guests) && guests_rel.cached?
          lookup = {} of Int64 => Guest
          self.guests.each { |guest| lookup[guest.id.as(Int64)] = guest }
          self.attendees.each do |attending|
            guest = lookup[attending.guest_id]
            guest.checked_in = attending.checked_in
          end
        end
      end
    end

    before_create :set_created

    validate :timezone, "required for recurring bookings", ->(this : self) { this.recurrence_type.none? ? true : !this.timezone.presence.nil? }
    validate :timezone, "must be a valid IANA timezone", ->(this : self) do
      if tz = this.timezone.presence
        begin
          Time::Location.load(tz)
          true
        rescue
          false
        end
      else
        true
      end
    end
    validate :booking_start, "must not clash with an existing booking", ->(this : self) { !this.clashing? }
    validate :asset_ids, "must be unique", ->(this : self) { this.unique_ids? }
    validate :booking_end, "must be after booking_start", ->(this : self) { this.booking_end > this.booking_start }
    validate :instance, "must not be set", ->(this : self) { this.instance.nil? }

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
      update_assets
      survey_trigger
    end

    before_update :cleanup_recurring_instances

    def update_assets
      if asset_ids.size == 1 && !@asset_ids_changed && @asset_id_changed
        asset_ids[0] = asset_id
        @asset_ids_changed = true
      elsif asset_ids.empty?
        asset_ids.insert(0, asset_id)
        @asset_ids_changed = true
      end
      self.asset_id = asset_ids.first
    end

    def asset_ids=(vals : Array(String))
      @asset_ids = vals
      @asset_ids_changed = true
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
      @asset_id ||= self.asset_ids.first unless self.asset_ids.empty?
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
      by_user_or_email(user_id_value, user_email_value, include_booked_by, false, false)
    end

    scope :by_user_or_email do |user_id_value, user_email_value, include_booked_by, include_open_permission, include_public_permission|
      # TODO: Construct `user_or_email` query correctly
      booked_by = include_booked_by ? %( OR "booked_by_id" = '#{user_id_value}') : ""
      open_permission = include_open_permission ? %( OR "permission" = 'OPEN') : ""
      public_permission = include_public_permission ? %( OR "permission" = 'PUBLIC') : ""
      user_id_value = user_id_value.try &.gsub(/[\'\"\)\(\\\/\$\?\;\:\<\>\+\=\*\&\^\#\!\`\%\}\{\[\]]/, "")
      user_email_value = user_email_value.try &.gsub(/[\'\"\)\(\\\/\$\?\;\:\<\>\=\*\&\^\!\`\%\}\{\[\]]/, "")

      user_email_digest = PlaceOS::Model::Email.new(user_email_value.to_s).digest if user_email_value

      if user_id_value && user_email_digest
        where("user_id = ? OR email_digest = ? #{booked_by} #{open_permission} #{public_permission}", user_id_value, user_email_digest)
      elsif user_id_value
        where("user_id = ? #{booked_by} #{open_permission} #{public_permission}", user_id_value)
      elsif user_email_digest
        booked_by = include_booked_by ? %( OR "booked_by_email_digest" = '#{user_email_digest}') : ""
        where("email_digest = ? #{booked_by} #{open_permission} #{public_permission}", user_email_digest)
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
          query = query.where(sql: "bookings.extension_data @> '#{PlaceOS::Model::JSONBQuery.to_query(split_entry[0], split_entry[1])}'")
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
        if check
          where(checked_in: check)
        else
          # checked_in defaults to false, so only checked out if checked_out_at is set
          where("checked_out_at IS NOT NULL AND bookings.checked_in = ?", check)
        end
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

    def unique_ids?
      update_assets
      unique_ids = self.asset_ids.uniq
      unique_ids.size == self.asset_ids.size
    end

    def clashing? : Bool
      return false if self.deleted || self.rejected || self.checked_out_at
      clashing_bookings.size > 0
    end

    protected def recurring_clash_check : Array(Booking)
      # we need to check for clashes against each recurrence
      starting = self.booking_start
      ending = self.booking_end

      # invalid booking, other validation will raise
      begin
        Time::Location.load self.timezone.as(String)
      rescue
        return [] of Booking
      end

      # 24 time -- 08:23:00, 13:30:00 etc
      start_time = Time.unix(starting).to_s("%T")
      end_time = Time.unix(ending).to_s("%T")

      # calculate the period we want to check for clashes
      max_period = 90.days
      if rec_ending = self.recurrence_end
        time_period = rec_ending - starting
        rec_ending = max_period.from_now.to_unix if time_period > max_period.total_seconds.to_i64
      else
        rec_ending = max_period.from_now.to_unix
      end

      overrides = Booking.find_all_by_sql(<<-SQL, tenant_id, rec_ending, starting, end_time, start_time, booking_type)
        SELECT b.* FROM "bookings" b
        JOIN booking_instances i ON b.id = i.id
        WHERE b.tenant_id = $1
          AND i.booking_start < $2
          AND i.booking_end > $3
          AND i.starting_time < $4
          AND i.ending_time > $5
          AND i.checked_out_at IS NULL
          AND b.booking_type = $6
          AND b.asset_ids && #{Associations.format_list_for_postgres(asset_ids)}
          AND b.rejected <> TRUE
          AND i.deleted <> TRUE
      SQL

      rec_ending_tz = Time.unix(rec_ending)
      if tz = self.timezone
        rec_ending_tz = rec_ending_tz.in(Time::Location.load tz)
      end

      expanded = Booking.expand_bookings!(starting_tz, rec_ending_tz, [self]).bookings

      # starting - booking_length ensures we capture overlaps
      query = Booking
        .by_tenant(tenant_id)
        .where(
          "(((recurrence_end > ? OR recurrence_end IS NULL) AND recurrence_type <> 'NONE') OR (booking_end > ? AND booking_start < ?)) AND checked_out_at IS NULL AND starting_time < ? AND ending_time > ? AND booking_type = ? AND asset_ids && #{Associations.format_list_for_postgres(asset_ids)} AND rejected <> TRUE AND deleted <> TRUE",
          starting, starting, rec_ending, end_time, start_time, booking_type
        )
      query = query.where("id != ?", id) unless id.nil?
      Booking.expand_bookings!(starting_tz, rec_ending_tz, query.to_a + overrides).bookings.select! do |other_booking|
        expanded.find { |this_booking| this_booking.booking_start < other_booking.booking_end && this_booking.booking_end > other_booking.booking_start }
      end
    end

    protected def regular_clash_check : Array(Booking)
      starting = self.booking_start
      ending = self.booking_end

      clashing = BookingInstance.find_one_by_sql?(<<-SQL, tenant_id, ending, starting, booking_type)
        SELECT i.* FROM "booking_instances" i
        JOIN bookings b ON i.id = b.id
        WHERE i.tenant_id = $1
          AND i.booking_start < $2
          AND i.booking_end > $3
          AND i.checked_out_at IS NULL
          AND b.booking_type = $4
          AND b.asset_ids && #{Associations.format_list_for_postgres(asset_ids)}
          AND b.rejected <> TRUE
          AND i.deleted <> TRUE
        LIMIT 1
      SQL
      return [clashing.hydrate_booking] if clashing

      # find any valid recurring bookings in the time period
      query = Booking
        .by_tenant(tenant_id)
        .where(
          "(((recurrence_end > ? OR recurrence_end IS NULL) AND recurrence_type <> 'NONE' AND booking_start < ?) OR (booking_start < ? AND booking_end > ?)) AND checked_out_at IS NULL AND booking_type = ? AND asset_ids && #{Associations.format_list_for_postgres(asset_ids)} AND rejected <> TRUE AND deleted <> TRUE",
          starting, ending, ending, starting, booking_type
        )
      query = query.where("id != ?", id) unless id.nil?
      Booking.expand_bookings!(starting_tz, ending_tz, query.to_a).bookings
    end

    def clashing_bookings : Array(Booking)
      update_assets

      # we need to check for clashes against each recurrence
      starting = self.booking_start
      ending = self.booking_end

      # find any overrides that might clash with the bookings
      candidates = if recurring_booking?
                     recurring_clash_check
                   else
                     regular_clash_check
                   end

      # we need to do this as booking instances may only set checked out / deleted flags
      # so the early clashing check misses these
      candidates.reject! { |booking| booking.checked_out_at || booking.rejected || booking.deleted }
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
        meta.render_linked_bookings = false
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
          linked_bookings = Booking.where(parent_id: id)
          clashing = linked_bookings.select do |booking|
            booking.booking_start = booking_start
            booking.booking_end = booking_end
            booking.clashing?
          end

          # reject clashing bookings
          Booking.where({:id => clashing.map(&.id)}).update_all({:rejected => true, :rejected_at => Time.utc.to_unix}) unless clashing.empty?

          # ensure the booking times are in sync
          Booking.where(parent_id: id).update_all({:booking_start => booking_start, :booking_end => booking_end})
        elsif deleted_changed? || deleted_at_changed?
          Booking.where(parent_id: id).update_all({:deleted => deleted, :deleted_at => deleted_at})
        elsif approved_changed? || approved_at_changed? || rejected_changed? || rejected_at_changed? || approver_id_changed? || approver_name_changed? || approver_email_changed?
          Booking.where(parent_id: id).update_all({:approved => approved, :approved_at => approved_at, :rejected => rejected, :rejected_at => rejected_at, :approver_id => approver_id, :approver_name => approver_name, :approver_email => approver_email})
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
      !event_id.nil?
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

    # ===
    # Recurring booking expansion
    # ===

    def recurring_booking? : Bool
      !recurrence_type.none? && !deleted && !rejected && instance.nil?
    end

    def recurring_instance? : Bool
      !instance.nil?
    end

    record ExpansionDetails,
      bookings : Array(Booking),
      complete : Int32, # number of recurring bookings completed
      next_idx : Int32  # number of recurring instances returned of current

    DEFAULT_LIMIT = 100_000

    # modifies the array, injecting the recurrences
    # ameba:disable Metrics/CyclomaticComplexity
    def self.expand_bookings!(
      starting : Time,
      ending : Time,
      parents : Array(Booking),
      limit : Int32 = DEFAULT_LIMIT,
      skip : Int32 = 0,
      is_checked_out : Bool? = nil
    ) : ExpansionDetails
      recurring = parents.select(&.recurring_booking?)
      return ExpansionDetails.new(parents, 0, 0) if recurring.empty?
      parent_ids = recurring.compact_map(&.id)
      recurring.each { |booking| parents.delete booking }

      # track limits
      remaining_limit = (limit - parents.size) + skip
      complete = 0
      next_idx = 0

      # calculate all the occurances in range
      booking_recurrences = {} of Int64 => Array(Int64)
      all_recurrences = Set(Int64).new
      recurring.each do |booking|
        details = case booking.recurrence_type
                  in .daily?
                    booking.calculate_daily(starting, ending, limit: remaining_limit)
                  in .weekly?
                    booking.calculate_weekly(starting, ending, limit: remaining_limit)
                  in .monthly?
                    booking.calculate_monthly(starting, ending, limit: remaining_limit)
                  in .none?
                    next
                  end

        instances = details.instances.map(&.to_unix)
        next_idx = instances.size

        # NOTE:: we can probably improve this skip by perfoming it as part of the
        # recurrence calculations, if this turns out to be a bottle neck
        if skip > 0
          instances = instances.size > skip ? instances[skip..-1] : [] of Int64
          skip = 0
          remaining_limit = limit - parents.size - instances.size
        else
          remaining_limit -= instances.size
        end

        booking_recurrences[booking.id || 0_i64] = instances
        all_recurrences.concat instances

        if details.limit_reached
          break
        else
          next_idx = 0
          complete += 1
        end
      end

      # find any manual adjustments
      instance_override = if parent_ids.empty? || all_recurrences.empty?
                            {} of Int64 => Array(BookingInstance)
                          else
                            BookingInstance.where(
                              %[id IN (#{parent_ids.join(", ")}) AND instance_start IN (#{all_recurrences.join(", ")})]
                            ).to_a.group_by(&.id.as(Int64))
                          end

      # apply the overrides
      starting_unix = starting.to_unix
      ending_unix = ending.to_unix
      recurring.each do |booking|
        booking_id = booking.id || 0_i64
        instances = booking_recurrences[booking_id]? || [] of Int64
        overrides = instance_override[booking_id]? || [] of BookingInstance

        instances = instances.compact_map do |starting_at|
          if override = overrides.find { |inst| inst.instance_start == starting_at }
            # ensure the override is within the queried range
            override.hydrate_booking(booking) if override.booking_start < ending_unix && override.booking_end > starting_unix
          else
            booking.hydrate_instance(starting_at)
          end
        end

        case is_checked_out
        when nil
          # we want to keep both checked in and out
        when true
          instances.select!(&.checked_out_at)
        when false
          instances.reject!(&.checked_out_at)
        end

        parents.concat instances
      end

      # remove anything not in the range, sort on creation date
      parents.select! do |booking|
        booking.booking_start < ending_unix && booking.booking_end > starting_unix
      end
      ExpansionDetails.new(parents, complete, next_idx)
    end

    def hydrate_instance(starting_at : Int64) : Booking
      booking_length = self.booking_end - self.booking_start
      other = self.dup
      other.booking_start = starting_at
      other.booking_end = starting_at + booking_length
      other.instance = starting_at
      other
    end

    def to_instance(starting_at : Int64 = self.booking_start)
      booking_length = self.booking_end - self.booking_start
      instance = BookingInstance.new(
        id: self.id.as(Int64),
        instance_start: starting_at,
        tenant_id: tenant_id.as(Int64),
        booking_start: starting_at,
        booking_end: starting_at + booking_length,
        checked_in: self.checked_in,
        checked_in_at: self.checked_in_at,
        checked_out_at: self.checked_out_at,
        deleted: self.deleted,
        deleted_at: self.deleted_at
      )
      instance.parent_booking = self
      instance
    end

    def as_instance
      inst_id = self.instance
      raise TypeCastError.new("Cast from Booking to BookingInstance failed. Not an instance") unless inst_id

      if inst = BookingInstance.find_one_by_sql?(<<-SQL, self.id, inst_id)
          SELECT i.* FROM "booking_instances" i
          WHERE i.id = $1
            AND i.instance_start = $2
          LIMIT 1
        SQL
        inst.booking_start = self.booking_start if self.booking_start_changed?
        inst.booking_end = self.booking_end if self.booking_end_changed?
        inst.checked_in = self.checked_in if self.checked_in_changed?
        inst.checked_in_at = self.checked_in_at if self.checked_in_at_changed?
        inst.checked_out_at = self.checked_out_at if self.checked_out_at_changed?
        inst.deleted = self.deleted if self.deleted_changed?
        inst.deleted_at = self.deleted_at if self.deleted_at_changed?
      else
        original_start = if change = self.booking_start_change
                           (change[0] || change[1]).as(Int64)
                         else
                           self.booking_start.as(Int64)
                         end
        original_end = if change = self.booking_end_change
                         (change[0] || change[1]).as(Int64)
                       else
                         self.booking_end.as(Int64)
                       end
        booking_length = original_end - original_start

        starting = self.booking_start_changed? ? self.booking_start : inst_id
        ending = self.booking_end_changed? ? self.booking_end : starting.as(Int64) + booking_length

        inst = BookingInstance.new(
          id: self.id.as(Int64),
          instance_start: inst_id,
          tenant_id: self.tenant_id.as(Int64),
          booking_start: starting,
          booking_end: ending,
          checked_in: self.checked_in,
          checked_in_at: self.checked_in_at,
          checked_out_at: self.checked_out_at,
          deleted: self.deleted,
          deleted_at: self.deleted_at
        )
      end

      inst.extension_data = self.extension_data if self.extension_data_changed?
      inst.parent_booking = self
      inst
    end

    DAY_BITS = {
      Time::DayOfWeek::Sunday    => 1,
      Time::DayOfWeek::Monday    => 1 << 1,
      Time::DayOfWeek::Tuesday   => 1 << 2,
      Time::DayOfWeek::Wednesday => 1 << 3,
      Time::DayOfWeek::Thursday  => 1 << 4,
      Time::DayOfWeek::Friday    => 1 << 5,
      Time::DayOfWeek::Saturday  => 1 << 6,
    }

    @[JSON::Field(ignore: true)]
    getter recurrence_on : Array(Time::DayOfWeek) do
      bitmap = self.recurrence_days
      DAY_BITS.compact_map do |(day, bit)|
        (bitmap & bit) > 0 ? day : nil
      end
    end

    # reset recurrence_on when the bitmap changes
    macro finished
      def recurrence_days=(bitmap : Int32)
        previous_def(bitmap)
        @recurrence_on = nil
        bitmap
      end

      def save
        if self.instance.nil?
          super
        else
          as_instance.save
        end
      end

      def save!
        if self.instance.nil?
          super
        else
          as_instance.save!
          self
        end
      end
    end

    record RecurrenceDetails, instances : Array(Time), limit_reached : Bool

    def calculate_daily(start_date : Time, end_date : Time, multiplier : Int32 = 1, limit : Int32 = Int32::MAX) : RecurrenceDetails
      occurrences = [] of Time

      time_zone = Time::Location.load(self.timezone.as(String))
      end_date = end_date.in(time_zone)
      start_date = start_date.in(time_zone)
      interval = (self.recurrence_interval || 1) * multiplier
      parent_booking_start = Time.unix(booking_start).in(time_zone)
      occurrence_end = self.recurrence_end ? Time.unix(self.recurrence_end.as(Int64)) : nil

      # ensure we capture any meeting that overlaps with the start of this time period
      booking_period = (self.booking_end - self.booking_start).seconds
      adjusted_start_date = start_date - booking_period

      # calculate the first occurrence after start_date
      days_since_start = ((adjusted_start_date - parent_booking_start) / 1.day).to_i
      intervals_since_start = days_since_start // interval
      first_occurrence_after_start = parent_booking_start.shift(days: intervals_since_start * interval)

      # generate the occurrences
      current_start = first_occurrence_after_start > parent_booking_start ? first_occurrence_after_start : parent_booking_start
      count = 0
      while current_start < end_date
        break if occurrence_end && current_start >= occurrence_end
        return RecurrenceDetails.new(occurrences, true) if count >= limit
        current_end = current_start + booking_period

        if current_end >= start_date &&
           self.recurrence_on.includes?(current_start.day_of_week)
          occurrences << current_start
          count += 1
        end
        current_start = current_start.shift(days: interval)
      end

      RecurrenceDetails.new(occurrences, false)
    end

    def calculate_weekly(start_date : Time, end_date : Time, limit : Int32 = Int32::MAX) : RecurrenceDetails
      self.recurrence_days = 0b1111111 unless self.recurrence_days == 0b1111111
      calculate_daily(start_date, end_date, multiplier: 7, limit: limit)
    end

    def calculate_monthly(start_date : Time, end_date : Time, limit : Int32 = Int32::MAX) : RecurrenceDetails
      occurrences = [] of Time

      time_zone = Time::Location.load(self.timezone.as(String))
      end_date = end_date.in(time_zone)
      start_date = start_date.in(time_zone)
      interval = self.recurrence_interval || 1
      parent_booking_start = Time.unix(booking_start).in(time_zone)
      occurrence_end = self.recurrence_end ? Time.unix(self.recurrence_end.as(Int64)) : nil

      # ensure we capture any meeting that overlaps with the start of this time period
      booking_period = (self.booking_end - self.booking_start).seconds
      adjusted_start_date = start_date - booking_period

      # calculate the first occurrence after start_date
      if adjusted_start_date > parent_booking_start
        starting_year = adjusted_start_date.year
        first_month = first_recurrence_month(parent_booking_start, interval, starting_year)
        day_of_month = get_nth_weekday_of_month(starting_year, first_month, self.recurrence_nth_of_month, recurrence_on, time_zone)
        current_start = Time.local(starting_year, first_month, day_of_month, parent_booking_start.hour, parent_booking_start.minute, parent_booking_start.second, location: time_zone)
      else
        current_start = parent_booking_start
        day_of_month = parent_booking_start.day
      end

      count = 0
      while current_start < end_date
        break if occurrence_end && current_start >= occurrence_end
        return RecurrenceDetails.new(occurrences, true) if count >= limit

        # add booking
        current_end = current_start + booking_period
        if current_end >= start_date
          occurrences << current_start
          count += 1
        end

        # calculate next occurrence
        current_start = current_start.at_beginning_of_month.shift(months: interval)
        day_of_month = get_nth_weekday_of_month(current_start.year, current_start.month, self.recurrence_nth_of_month, recurrence_on, time_zone)
        current_start = Time.local(current_start.year, current_start.month, day_of_month, parent_booking_start.hour, parent_booking_start.minute, parent_booking_start.second, location: time_zone)
      end

      RecurrenceDetails.new(occurrences, false)
    end

    def first_recurrence_month(start_date : Time, interval_months : Int32, year : Int32) : Int32
      # Calculate the total months difference from start_date to the beginning of the target year
      start_year = start_date.year
      start_month = start_date.month
      total_months_from_start = (year - start_year) * 12 + (1 - start_month)

      # Find the first meeting month in the target year
      months_to_first_meeting = interval_months - (total_months_from_start % interval_months)
      start_date.shift(months: total_months_from_start + months_to_first_meeting).month
    end

    # Helper function to find the nth day of a month
    def get_nth_weekday_of_month(year : Int32, month : Int32, nth : Int32, valid_days : Array(Time::DayOfWeek), time_zone : Time::Location) : Int32
      if nth > 0
        current_day = Time.local(year, month, 1, location: time_zone)
        # find the first valid day
        loop do
          break if valid_days.includes? current_day.day_of_week
          current_day = current_day.shift days: 1
        end
        current_day.shift(days: (nth - 1) * 7).day
      else
        current_day = Time.local(year, month, Time.days_in_month(year, month), location: time_zone)
        loop do
          break if valid_days.includes? current_day.day_of_week
          current_day = current_day.shift days: -1
        end
        current_day.shift(days: (nth + 1) * 7).day
      end
    end

    # remove any instance overrides if start times have changed
    def cleanup_recurring_instances : Nil
      return unless self.booking_start_changed?
      BookingInstance.where(id: self.id).delete_all
    end
  end
end
