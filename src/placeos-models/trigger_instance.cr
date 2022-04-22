require "random"
require "rethinkdb-orm"
require "time"

require "./base/model"

module PlaceOS::Model
  class TriggerInstance < ModelBase
    include RethinkORM::Timestamps

    table :trig

    attribute enabled : Bool = true
    attribute triggered : Bool = false
    attribute important : Bool = false
    attribute exec_enabled : Bool = false

    attribute webhook_secret : String = ->{ Random::Secure.urlsafe_base64(32) }
    attribute trigger_count : Int32 = 0

    # Association
    ################################################################################################

    belongs_to ControlSystem, foreign_key: "control_system_id"
    belongs_to Trigger, foreign_key: "trigger_id"
    belongs_to Zone, foreign_key: "zone_id"

    # Validation
    ################################################################################################

    validates :control_system, presence: true
    validates :trigger, presence: true

    # Callbacks
    ################################################################################################

    before_create :set_importance

    protected def set_importance
      if (trig = self.trigger)
        self.important = trig.important
      end
    end

    # Queries
    ################################################################################################

    # Look up `TriggerInstance`s by `ControlSystem`
    def self.for(control_system_id)
      TriggerInstance.by_control_system_id(control_system_id)
    end

    # Look up `TriggerInstance`s belonging to `Trigger`
    def self.of(trigger_id)
      TriggerInstance.by_trigger_id(trigger_id)
    end

    # Serialisation
    ################################################################################################

    define_to_json :metadata, methods: [:name, :description, :conditions, :actions, :binding]

    # Override to_json, set method fields
    @[Deprecated("Use `#to_metadata_json` instead.")]
    def as_json
      to_metadata_json
    end

    # TriggerInstance State
    ################################################################################################

    # Enables the trigger
    #
    def start
      toggle_trigger(true)
    end

    # Disables the trigger
    #
    def stop
      toggle_trigger(false)
    end

    protected def toggle_trigger(on : Bool)
      self.update_fields(enabled: on)
    end

    # Increment the `trigger_count` of a `TriggerInstance` in place.
    #
    def self.increment_trigger_count(id : String)
      TriggerInstance.table_query do |q|
        q.get(id).update do |doc|
          doc.merge({"trigger_count" => doc["trigger_count"].add(1)})
        end
      end
    end

    # Proxied `Trigger` attributes
    ################################################################################################

    {% begin %}
      {% for attr in {:name, :description, :conditions, :actions, :debounce_period} %}
        # Proxies the parent `Trigger`'s {{attr.id}} attribute.
        def {{ attr.id }}
          trigger.try &.{{ attr.id }}
        end
      {% end %}
    {% end %}
  end
end
