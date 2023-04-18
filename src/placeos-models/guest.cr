require "json"
require "./base/model"
require "./tenant"
require "./attendee"
require "./booking"
require "./event_metadata"

module PlaceOS::Model
  class Guest < ModelWithAutoKey
    table :guests
    attribute email : String, format: "email"
    attribute name : String?
    attribute preferred_name : String?
    attribute phone : String?
    attribute organisation : String?
    attribute notes : String?
    attribute photo : String?
    attribute banned : Bool = false
    attribute dangerous : Bool = false
    attribute searchable : String?
    attribute extension_data : JSON::Any = JSON::Any.new(Hash(String, JSON::Any).new)

    attribute checked_in : Bool?, persistence: false, show: true, ignore_deserialize: true
    attribute visit_expected : Bool?, persistence: false, show: true, ignore_deserialize: true
    attribute booking : Booking?, persistence: false, show: true, ignore_deserialize: true
    attribute event : PlaceCalendar::Event?, persistence: false, show: true, ignore_deserialize: true
    attribute event_metadata : String?, persistence: false, converter: String::RawConverter, show: true, ignore_deserialize: true

    attribute booking_rep : Booking? = nil, persistence: false, show: true, json_key: "booking", ignore_deserialize: true

    belongs_to Tenant, pk_type: Int64

    has_many(
      child_class: Attendee,
      collection_name: "attendees",
      foreign_key: "guest_id",
      dependent: :destroy
    )

    # Save searchable information
    before_save do
      @email = email.strip.downcase
      @searchable = String.build do |sb|
        sb << email
        sb << " #{name}" if name_assigned?
        sb << " #{preferred_name}" if preferred_name_assigned?
        sb << " #{organisation}" if organisation_assigned?
        sb << " #{phone}" if phone_assigned?
        sb << " #{id}" if id_assigned?
      end.downcase
    end

    def change_extension_data(data : JSON::Any)
      @extension_data = data
      @extension_data_changed = true
    end

    scope :by_tenant do |tenant_id|
      where(tenant_id: tenant_id)
    end

    def to_h(visitor : Attendee?, is_parent_metadata, meeting_details : PlaceCalendar::Event?)
      self.checked_in = is_parent_metadata ? false : visitor.try(&.checked_in) || false
      self.visit_expected = visitor.try(&.visit_expected) || false
      if meeting_details
        self.event = meeting_details
      elsif meta = visitor.try(&.event_metadata)
        self.event_metadata = meta.to_json
      end
      self
    end

    def for_booking_to_h(visitor : Attendee, booking_details : Booking?)
      self.checked_in = visitor.checked_in || false
      self.visit_expected = visitor.visit_expected || false
      self.booking_rep = booking_details if booking_details
      self
    end

    def attending_today(tenant_id, timezone)
      now = Time.local(timezone)
      morning = now.at_beginning_of_day.to_unix
      tonight = now.at_end_of_day.to_unix

      Attendee.find_one_by_sql?(<<-SQL, tenant_id, id.not_nil!, morning, tonight)
        SELECT a.* FROM "attendees" a LEFT OUTER JOIN "event_metadatas" m ON (m.id = a.event_id AND m.event_start >= $3 AND m.event_end <= $4)
        LEFT OUTER JOIN "bookings" b ON (b.id = a.booking_id AND b.booking_start >= $3 and b.booking_end <= $4)
        WHERE a.tenant_id = $1 AND a.guest_id = $2
      SQL
    end

    def events(future_only = true, limit = 10)
      if future_only
        EventMetadata.find_all_by_sql(<<-SQL, id.not_nil!, Time.utc.to_unix, limit)
          SELECT m.* from "event_metadatas" m INNER JOIN "attendees" a ON a.event_id = m.id
          WHERE a.guest_id = $1 AND m.event_end >= $2 ORDER BY m.event_start ASC LIMIT $3
        SQL
      else
        EventMetadata.find_all_by_sql(<<-SQL, id.not_nil!, limit)
        SELECT m.* from "event_metadatas" m INNER JOIN "attendees" a ON a.event_id = m.id
          WHERE a.guest_id = $1 ORDER BY m.event_start ASC LIMIT $2
        SQL
      end
    end

    def bookings(future_only = true, limit = 10)
      if future_only
        Booking.find_all_by_sql(<<-SQL, id.not_nil!, Time.utc.to_unix, limit)
          SELECT b.* from "bookings" b INNER JOIN "attendees" a ON a.booking_id = b.id
          WHERE a.guest_id = $1 AND b.booking_end >= $2 ORDER BY b.booking_start ASC LIMIT $3
        SQL
      else
        Booking.find_all_by_sql(<<-SQL, id.not_nil!, limit)
          SELECT b.* from "bookings" b INNER JOIN "attendees" a ON a.booking_id = b.id
          WHERE a.guest_id = $1 ORDER BY b.booking_start ASC LIMIT $2
        SQL
      end
    end

    def attendee_for(event_id)
      Attendee.create!(
        event_id: event_id,
        guest_id: self.id,
        tenant_id: self.tenant_id,
        checked_in: false,
        visit_expected: true,
      )
    end

    def patch(changes : self)
      {% for key in %i(email name preferred_name phone organisation notes photo dangerous banned) %}
      begin
        self.{{key.id}} = changes.{{key.id}} if changes.{{key.id}}_present?
      rescue NilAssertionError
      end
    {% end %}

      extension_data = changes.extension_data if changes.extension_data_present?
      if extension_data
        guest_ext_data = self.extension_data
        data = guest_ext_data ? guest_ext_data.as_h : Hash(String, JSON::Any).new
        extension_data.not_nil!.as_h.each { |key, value| data[key] = value }
        self.change_extension_data(JSON::Any.new(data))
      end

      self.save!
    end
  end
end
