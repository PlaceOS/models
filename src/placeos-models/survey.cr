require "json"
require "./base/model"
require "./utilities/encryption"
require "./tenant/outlook_config"
require "./guest"
require "./event_metadata"
require "./survey/*"

module PlaceOS::Model
  class Survey < ModelWithAutoKey
    table :surveys

    enum TriggerType
      NONE
      RESERVED
      CHECKEDIN
      CHECKEDOUT
      NOSHOW
      REJECTED
      CANCELLED
      ENDED
      VISITOR_CHECKEDIN
      VISITOR_CHECKEDOUT
    end

    attribute title : String, sanitize: :text
    attribute description : String = "", sanitize: :common
    attribute trigger : TriggerType = TriggerType::NONE, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::Survey::TriggerType),
      description: "Triggers on booking states: RESERVED, CHECKEDIN, CHECKEDOUT, REJECTED, CANCELLED, VISITOR_CHECKEDIN, VISITOR_CHECKEDOUT"
    # the zone (e.g. a level, area or the organisation) and/or building the survey applies to,
    # at least one is required. The database clears them if the zone is deleted
    attribute zone_id : String? = nil
    attribute building_id : String? = nil
    attribute pages : Array(Survey::Page) = [] of Survey::Page, converter: PlaceOS::Model::DBArrConverter(PlaceOS::Model::Survey::Page)

    # NOTE: nilable at the DB level so existing surveys can be adopted by an authority,
    # but required at the model level (see the presence validation below)
    belongs_to Authority, foreign_key: "authority_id"

    has_many(
      child_class: Survey::Answer,
      collection_name: "answers",
      foreign_key: "survey_id",
      dependent: :destroy
    )

    validates :title, :pages, :authority_id, presence: true

    validate ->(this : Survey) {
      # clients may send empty strings for an unset zone
      this.zone_id = this.zone_id.presence
      this.building_id = this.building_id.presence
      this.validation_error(:zone_id, "zone_id or building_id is required") unless this.zone_id || this.building_id
    }

    # the zones a survey applies to, building first so the more specific zone is checked last
    def zones : Array(String)
      [building_id.presence, zone_id.presence].compact
    end

    # surveys that send invitations when a booking or visitor in `zones` changes to `trigger`.
    # A survey with only a zone_id or only a building_id must match that zone, one with both
    # must match both. Nothing is triggered without zones to match on
    def self.triggered_by(trigger : TriggerType, zones : Array(String)?) : Array(self)
      return [] of self if zones.nil? || zones.empty?

      zone_list = Array.new(zones.size, "?").join(", ")
      Survey.select("id")
        .where(trigger: trigger.to_s)
        .where(
          "(zone_id IS NOT NULL OR building_id IS NOT NULL) " \
          "AND (zone_id IS NULL OR zone_id IN (#{zone_list})) " \
          "AND (building_id IS NULL OR building_id IN (#{zone_list}))",
          zones + zones
        ).to_a
    end

    # assigns surveys created before surveys belonged to an authority, skipping validation
    def self.adopt_unowned(authority_id : String) : Nil
      Survey.where(authority_id: nil).update_all(authority_id: authority_id)
    end

    def question_ids
      pages.flat_map(&.question_order).uniq!
    end

    def self.missing_answers(survey_id : Int64, answers : Array(Survey::Answer))
      Question.required_question_ids(survey_id) - answers.map(&.question_id)
    end

    def self.list(zone_id : String? = nil, building_id : String? = nil, authority_id : String? = nil) : Array(self)
      query = Survey.select("id, title, description, trigger, zone_id, building_id, pages, authority_id")
      query = query.where(authority_id: authority_id) if authority_id
      query = query.where(zone_id: zone_id) if zone_id
      query = query.where(building_id: building_id) if building_id
      query.to_a
    end

    def patch(changes : self)
      {% for key in [:title, :description, :trigger, :zone_id, :building_id, :pages] %}
      begin
        self.{{key.id}} = changes.{{key.id}} if changes.{{key.id}}_present? || self.{{key.id}}.nil?
      rescue NilAssertionError
      end
      {% end %}
      self.save!
    end
  end
end
