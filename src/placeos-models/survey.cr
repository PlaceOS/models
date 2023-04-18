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
    end

    attribute title : String
    attribute description : String = ""
    attribute trigger : TriggerType = TriggerType::NONE, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::Survey::TriggerType)
    attribute zone_id : String = ""
    attribute building_id : String = ""
    attribute pages : Array(Survey::Page) = [] of Survey::Page, converter: PlaceOS::Model::DBArrConverter(PlaceOS::Model::Survey::Page)

    has_many(
      child_class: Survey::Answer,
      collection_name: "answers",
      foreign_key: "survey_id",
      dependent: :destroy
    )

    validates :title, :pages, presence: true

    def question_ids
      pages.flat_map(&.question_order).uniq!
    end

    def self.missing_answers(survey_id : Int64, answers : Array(Survey::Answer))
      Question.required_question_ids(survey_id) - answers.map(&.question_id)
    end

    def self.list(zone_id : String? = nil, building_id : String? = nil) : Array(self)
      query = Survey.select("id, title, description, trigger, zone_id, building_id, pages")
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
