require "rethinkdb-orm"
require "time"
require "uri"
require "future"

require "./base/model"
require "./settings"
require "./utilities/settings_helper"
require "./utilities/time_location_converter"

module PlaceOS::Model
  class ControlSystem < ModelBase
    include RethinkORM::Timestamps
    include SettingsHelper

    table :sys

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""

    # Room search meta-data
    # Building + Level are both filtered using zones
    attribute features : Set(String) = ->{ Set(String).new }
    attribute email : String?
    attribute bookable : Bool = false
    attribute display_name : String?
    attribute code : String?
    attribute type : String?
    attribute capacity : Int32 = 0
    attribute map_id : String?

    # Array of URLs to images for a system
    attribute images : Array(String) = ->{ [] of String }

    attribute timezone : Time::Location?, converter: Time::Location::Converter, es_type: "text"

    # Provide a field for simplifying support
    attribute support_url : String = ""

    attribute version : Int32 = 0

    # The number of UI devices that are always available in the room
    # i.e. the number of iPads mounted on the wall
    attribute installed_ui_devices : Int32 = 0

    # IDs of associated models
    attribute zones : Array(String) = [] of String, es_type: "keyword"
    attribute modules : Array(String) = [] of String, es_type: "keyword"

    # Associations
    ###############################################################################################

    # Encrypted yaml settings, with metadata
    has_many(
      child_class: Settings,
      collection_name: "settings",
      foreign_key: "parent_id",
      dependent: :destroy
    )

    # Metadata belonging to this control_system
    has_many(
      child_class: Metadata,
      collection_name: "metadata",
      foreign_key: "parent_id",
      dependent: :destroy
    )

    # Single System triggers
    has_many(
      child_class: Trigger,
      dependent: :destroy,
      collection_name: :system_triggers,
      foreign_key: "control_system_id"
    )

    # Provide a email lookup helpers
    secondary_index :email

    # Validation
    ###############################################################################################

    # Zones and settings are only required for confident coding
    validates :name, presence: true

    # TODO: Ensure unique regardless of casing
    ensure_unique :name do |name|
      name.strip
    end

    # Validate support URI
    validate ->(this : ControlSystem) {
      return if this.support_url.blank?
      this.validation_error(:support_url, "is an invalid URI") unless Validation.valid_uri?(this.support_url)
    }

    # Queries
    ###############################################################################################

    def self.by_zone_id(id)
      ControlSystem.raw_query do |q|
        q.table(ControlSystem.table_name).filter do |doc|
          doc["zones"].contains(id)
        end
      end
    end

    @[Deprecated("Use `by_zone_id`")]
    def self.in_zone(id)
      self.by_zone_id(id)
    end

    def self.by_module_id(id)
      ControlSystem.raw_query do |q|
        q.table(ControlSystem.table_name).filter do |doc|
          doc["modules"].contains(id)
        end
      end
    end

    @[Deprecated("Use `by_module_id`")]
    def self.using_module(id)
      self.by_module_id(id)
    end

    # Obtains the control system's modules as json
    # FIXME: Dreadfully needs optimisation, i.e. subset serialisation
    def module_data
      Module.find_all(self.modules).to_a.map do |mod|
        # Pick off driver name, and module_name from associated driver
        driver_data = mod.driver.try do |driver|
          {
            :driver => {
              name:        driver.name,
              module_name: driver.module_name,
            },
          }
        end

        if driver_data
          JSON.parse(mod.to_json).as_h.merge(driver_data).to_json
        else
          mod.to_json
        end
      end
    end

    # Obtains the control system's zones as json
    def zone_data
      Zone.find_all(self.zones).to_a.map(&.to_json)
    end

    # Triggers
    def triggers
      TriggerInstance.for(self.id)
    end

    # Collect Settings ordered by hierarchy
    #
    # Control System < Zone/n < Zone/(n-1) < ... < Zone/0
    def settings_hierarchy : Array(Settings)
      # Start with Control System Settings
      settings = master_settings

      # Zone Settings
      zone_models = Model::Zone.find_all(self.zones).to_a
      # Merge by highest associated zone
      self.zones.reverse_each do |zone_id|
        next if (zone = zone_models.find &.id.==(zone_id)).nil?
        settings.concat(zone.master_settings)
      end

      settings.compact
    end

    # Callbacks
    ###############################################################################################

    before_save :update_features

    before_destroy :cleanup_modules

    before_save :check_zones

    after_save :update_triggers

    # Internal modules
    private IGNORED_MODULES = ["__Triggers__"]

    # Adds modules to the features field,
    # Extends features with extra_features field in settings if present
    protected def update_features
      module_names = Module
        .find_all(self.modules)
        .map(&.resolved_name)
        .select(&.in?(IGNORED_MODULES).!)
        .to_set
      self.features = self.features + module_names
    end

    # Remove Modules not associated with any other systems
    # NOTE: Includes compulsory associated Logic Modules
    def cleanup_modules
      return if self.modules.empty?

      # Locate modules that have no other associated ControlSystems
      lonesome_modules = Module.raw_query do |r|
        r.table(Module.table_name).get_all(self.modules).filter do |mod|
          # Find the control systems that have the module
          r.table(ControlSystem.table_name).filter do |sys|
            sys["modules"].contains(mod["id"])
          end.count.eq(1)
        end
      end

      # Asynchronously remove the modules
      lonesome_modules.map do |m|
        future { m.destroy }
      end.each(&.get)
    end

    private getter remove_zones : Array(String) { [] of String }
    private getter add_zones : Array(String) { [] of String }

    private property? update_triggers = false

    # Update the zones on the model
    protected def check_zones
      if self.zones_changed?
        previous = self.zones_was || [] of String
        current = self.zones

        @remove_zones = previous - current
        @add_zones = current - previous

        self.update_triggers = !remove_zones.empty? || !add_zones.empty?
      else
        self.update_triggers = false
      end
    end

    # Updates triggers after save
    #
    # - Destroy `Trigger`s from removed zones
    # - Adds `TriggerInstance`s to added zones
    protected def update_triggers
      return unless update_triggers?

      unless remove_zones.empty?
        trigger_models = self.triggers.to_a

        # Remove ControlSystem's triggers associated with the removed zone
        Zone.find_all(remove_zones).each do |zone|
          # Destroy the associated triggers
          zone.triggers.each do |trig_id|
            trigger_models.each do |trigger_model|
              # Ensure trigger is for the removed zone
              if trigger_model.trigger_id == trig_id && trigger_model.zone_id == zone.id
                trigger_model.destroy
              end
            end
          end
        end
      end

      # Add trigger instances to zones
      Zone.find_all(add_zones).each do |zone|
        zone.triggers.each do |trig_id|
          inst = TriggerInstance.new(trigger_id: trig_id, zone_id: zone.id)
          inst.control_system = self
          inst.save
        end
      end
    end

    # Module Management
    ###############################################################################################

    # Removes the module from the system and deletes it if not used elsewhere
    #
    def add_module(module_id : String)
      if !self.modules.includes?(module_id) && ControlSystem.add_module(id.as(String), module_id)
        self.modules << module_id
        self.version = ControlSystem.table_query(&.get(id.as(String))["version"]).as_i
      end
    end

    def self.add_module(control_system_id : String, module_id : String)
      response = Model::ControlSystem.table_query do |q|
        q
          .get(control_system_id)
          .update { |sys|
            {
              "modules" => sys["modules"].set_insert(module_id),
              "version" => sys["version"] + 1,
            }
          }
      end

      {"replaced", "updated"}.any? { |k| response[k].try(&.as_i) || 0 > 0 }
    end

    # Removes the module from the system and deletes it if not used elsewhere
    #
    def remove_module(module_id : String)
      mod = Module.find(module_id)
      if self.modules.includes?(module_id) && ControlSystem.remove_module(id.as(String), module_id)
        self.modules.delete(module_id)
        unless mod.nil?
          # Remove the module from the control system's features
          self.features.delete(mod.resolved_name)
          self.features.delete(mod.name)
        end
        self.version = ControlSystem.table_query(&.get(id.as(String))["version"]).as_i
      end
    end

    def self.remove_module(control_system_id : String, module_id : String)
      response = ControlSystem.table_query do |q|
        q
          .get(control_system_id)
          .update { |sys|
            {
              "modules" => sys["modules"].set_difference([module_id]),
              "version" => sys["version"] + 1,
            }
          }
      end

      return false unless {"replaced", "updated"}.any? { |k| response[k].try(&.as_i) || 0 > 0 }

      # Keep if any other ControlSystem is using the module
      still_in_use = ControlSystem.by_module_id(module_id).any? do |sys|
        sys.id != control_system_id
      end

      Module.find(module_id).try(&.destroy) if !still_in_use

      Log.debug { {
        message:           "module removed from system #{still_in_use ? "still in use" : "deleted as not in any other systems"}",
        module_id:         module_id,
        control_system_id: control_system_id,
      } }

      true
    end
  end
end
