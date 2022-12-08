require "json"
require "time"

require "./base/model"
require "./trigger/*"

module PlaceOS::Model
  class Trigger < ModelBase
    include PlaceOS::Model::Timestamps

    table :trigger

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""

    # Full path allows resolution in macros
    attribute actions : PlaceOS::Model::Trigger::Actions = ->{ Actions.new }, es_type: "object"
    attribute conditions : PlaceOS::Model::Trigger::Conditions = ->{ Conditions.new }, es_type: "object"

    # In milliseconds
    attribute debounce_period : Int32 = 0
    attribute important : Bool = false

    attribute enable_webhook : Bool = false

    METHODS = %w(GET POST PUT PATCH DELETE)
    attribute supported_methods : Array(String) = ["POST"]

    # Association
    ###############################################################################################

    has_many(
      child_class: TriggerInstance,
      dependent: :destroy,
      foreign_key: "trigger_id",
      collection_name: :trigger_instances
    )

    # Allows filtering in cases of a `Trigger` belonging to a single `ControlSystem`
    belongs_to ControlSystem, foreign_key: "control_system_id"

    # Validation
    ###############################################################################################

    # Validate `supported_methods`
    validate ->(this : Trigger) do
      invalid = this.supported_methods - METHODS
      this.validation_error(:supported_methods, "contains invalid methods: #{invalid.join(", ")}") unless invalid.empty?
    end

    # Validation of `actions` and `conditions`.
    validate ->(this : Trigger) do
      if !this.actions.valid?
        this.actions.errors.each do |e|
          this.validation_error(:action, e.to_s)
        end
      end

      if !this.conditions.valid?
        this.conditions.errors.each do |e|
          this.validation_error(:condition, e.to_s)
        end
      end
    end

    # Helpers
    ###############################################################################################

    def supported_method?(method : String)
      method.in? supported_methods
    end
  end
end
