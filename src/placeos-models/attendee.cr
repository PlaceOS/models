require "json"
require "./base/model"
require "./tenant"
require "./event_metadata"
require "./guest"
require "./booking"

module PlaceOS::Model
  class Attendee < ModelWithAutoKey
    table :attendees

    attribute checked_in : Bool
    attribute visit_expected : Bool
    attribute guest_id : Int64

    belongs_to Tenant, pk_type: Int64
    belongs_to EventMetadata, foreign_key: "event_id", pk_type: Int64
    belongs_to Booking, foreign_key: "booking_id", pk_type: Int64
    belongs_to Guest, pk_type: Int64

    getter(email : String) { guest.not_nil!.email }

    {% for key in [:name, :preferred_name, :phone, :organisation, :notes, :photo] %}
      getter({{key.id}} : String?){guest.not_nil!.{{key.id}}}
    {% end %}

    getter event : PlaceCalendar::Event? = nil

    before_save :survey_trigger
    after_save :sync_booking_checkin

    scope :by_tenant do |tenant_id|
      where(tenant_id: tenant_id)
    end

    def self.by_bookings(tenant_id, booking_ids)
      clause = build_clause(booking_ids, 2)
      Attendee.find_all_by_sql(<<-SQL, tenant_id, args: booking_ids)
        SELECT a.* from attendees a inner join bookings on bookings.id = a.booking_id
        inner join guests on guests.id = a.guest_id where a.tenant_id = $1 and a.booking_id in (#{clause})
      SQL
    end

    def survey_trigger
      return unless checked_in_changed?
      state = checked_in ? Survey::TriggerType::VISITOR_CHECKEDIN : Survey::TriggerType::VISITOR_CHECKEDOUT

      query = Survey.select("id").where(trigger: PlaceOS::Model::PGEnumConverter.to_json(state))

      if (b = booking) && (zones = b.zones) && !zones.empty?
        query = query.where({:zone_id => zones, :building_id => zones})
      end

      email = guest.not_nil!.email
      unless email.empty?
        surveys = query.to_a
        surveys.each do |survey|
          Survey::Invitation.create!(
            survey_id: survey.id,
            email: email,
          )
        end
      end
    end

    # a one way sync ensuring that the booking is checked in if a guest is
    def sync_booking_checkin
      return unless self.booking_id
      booking = self.booking
      if booking && self.checked_in
        booking.checked_in = true
        booking.checked_in_at ||= Time.utc.to_unix
        booking.save!
      end
    end

    def to_h(is_parent_metadata : Bool?, meeting_details : PlaceCalendar::Event?)
      self.checked_in = false if is_parent_metadata
      @event = meeting_details
      self
    end

    def for_booking?
      !booking_id.nil?
    end

    def to_json(json : ::JSON::Builder)
      # call these getters for values (if any) to get set, prior to invoking to_json
      {% for key in [:email, :name, :preferred_name, :phone, :organisation, :notes, :photo] %}
        {{key.id}}
      {% end %}
      super
    end
  end
end
