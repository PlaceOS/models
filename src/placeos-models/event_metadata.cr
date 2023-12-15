require "json"
require "./base/model"
require "./utilities/jsonb_query_helper"

module PlaceOS::Model
  class EventMetadata < ModelWithAutoKey
    table :event_metadatas

    attribute system_id : String
    attribute event_id : String
    attribute recurring_master_id : String?
    attribute ical_uid : String

    # this allows us to find the recurring master metadata from the resource calendar
    # annoying how hard this is to find on MS Graph API.
    attribute resource_master_id : String?

    attribute host_email : String
    attribute resource_calendar : String
    attribute event_start : Int64
    attribute event_end : Int64
    attribute cancelled : Bool = false

    attribute ext_data : JSON::Any?

    attribute setup_time : Int64 = 0
    attribute breakdown_time : Int64 = 0
    attribute setup_event_id : String? = nil
    attribute breakdown_event_id : String? = nil

    belongs_to Tenant, pk_type: Int64

    has_many(
      child_class: Attendee,
      collection_name: "attendees",
      foreign_key: "event_id",
      dependent: :destroy
    )

    has_many(
      child_class: Booking,
      collection_name: "bookings",
      foreign_key: "event_id",
      dependent: :destroy
    )

    @[JSON::Field(key: "linked_bookings", ignore_deserialize: true)]
    property linked_bookings : Array(Booking)? { Booking.where(event_id: self.id, deleted: false) }

    @[JSON::Field(ignore: true)]
    property? render_linked_bookings : Bool = true

    def to_json(json : ::JSON::Builder)
      if render_linked_bookings?
        @linked_bookings = bookings
          .join(:left, Attendee, :booking_id)
          .join(:left, Guest, "guests.id = attendees.guest_id")
          .to_a.tap(&.each(&.render_event=(false)))
      else
        @linked_bookings = nil
      end
      super
    end

    def set_ext_data(meta : JSON::Any)
      @ext_data = meta
      @ext_data_changed = true
    end

    scope :by_tenant do |tenant_id|
      where(tenant_id: tenant_id)
    end

    scope :by_ext_data do |field_name, value|
      where("ext_data @> ?", PlaceOS::Model::JSONBQuery.to_query(field_name, value))
    end

    scope :is_ending_after do |start_time|
      start_time ? where("event_end > ?", start_time.not_nil!.to_i64) : self
    end

    scope :is_starting_before do |end_time|
      end_time ? where("event_start < ?", end_time.not_nil!.to_i64) : self
    end

    scope :by_event_ids do |event_ids|
      if event_ids && !event_ids.empty?
        the_ids = event_ids.join("', '")
        where("event_id IN ('#{the_ids}') OR ical_uid IN ('#{the_ids}')", nil)
      else
        self
      end
    end

    scope :by_master_ids do |master_ids|
      if master_ids && !master_ids.empty?
        the_ids = master_ids.join("', '")
        where("recurring_master_id IN ('#{the_ids}') OR resource_master_id IN ('#{the_ids}')", nil)
      else
        self
      end
    end

    def for_event_instance?(event, client_id)
      if client_id == :office365
        # ical_uid is unique for every instance of an event in office365
        # https://devblogs.microsoft.com/microsoft365dev/microsoft-graph-calendar-events-icaluid-update/ (note, they created a new uid field)
        ical_uid == event.ical_uid
      else
        # for google the event_id is the same across all instances of an event
        # UID is as per the standard for google
        event_id == event.id
      end
    end

    # keep bookings in sync
    before_update do
      if event_start_changed? || event_end_changed?
        linked_bookings = self.bookings

        if linked_bookings.size > 0
          clashing = linked_bookings.select do |booking|
            booking.booking_start = event_start
            booking.booking_end = event_end
            booking.clashing?
          end

          # reject clashing bookings
          Booking.where({:id => clashing.map(&.id)}).update_all({:rejected => true, :rejected_at => Time.utc.to_unix}) unless clashing.empty?

          # ensure the booking times are in sync
          Booking.where(event_id: id).update_all({:booking_start => event_start, :booking_end => event_end})
        end
      end

      if cancelled_changed? && cancelled
        Booking.where(event_id: id).update_all({:rejected => true, :rejected_at => Time.utc.to_unix})
      end
    end

    def self.migrate_recurring_metadata(system_id : String, recurrance : PlaceCalendar::Event, parent_metadata : EventMetadata)
      metadata = EventMetadata.new

      PgORM::Database.transaction do
        metadata.update!(
          ext_data: parent_metadata.ext_data,
          tenant_id: parent_metadata.tenant_id,
          system_id: system_id,
          event_id: recurrance.id.not_nil!,
          recurring_master_id: recurrance.recurring_event_id,
          ical_uid: recurrance.ical_uid.not_nil!,
          event_start: recurrance.event_start.not_nil!.to_unix,
          event_end: recurrance.event_end.not_nil!.to_unix,
          resource_calendar: parent_metadata.resource_calendar,
          host_email: parent_metadata.host_email,
        )

        parent_metadata.attendees.where(visit_expected: true).each do |attendee|
          Attendee.create!(
            event_id: metadata.id.not_nil!,
            guest_id: attendee.guest_id,
            tenant_id: attendee.tenant_id,
            visit_expected: true,
            checked_in: false,
          )
        end
      end

      metadata
    end
  end
end
