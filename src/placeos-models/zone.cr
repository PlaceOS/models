require "time"

require "./base/model"
require "./settings"
require "./utilities/settings_helper"
require "./utilities/metadata_helper"
require "./converter/time_location"

module PlaceOS::Model
  class Zone < ModelBase
    include PlaceOS::Model::Timestamps
    include Utilities::SettingsHelper
    include Utilities::MetadataHelper

    table :zone

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""
    attribute tags : Set(String) = ->{ Set(String).new }

    # =============================
    # Additional top level metadata that is fairly common
    # =============================
    # Geo-location string (lat,long) or any other location
    attribute location : String?
    # For display on staff app
    attribute display_name : String?
    # Could be used as floor code
    attribute code : String?
    # Could be used as floor type
    attribute type : String?
    # Could be used as a desk count
    attribute count : Int32 = 0
    # Could be used as a people capacity
    attribute capacity : Int32 = 0
    # Map identifier, could be a URL or id
    attribute map_id : String?
    # Timezone
    attribute timezone : Time::Location?, converter: Time::Location::Converter, es_type: "text"
    # =============================

    attribute triggers : Array(String) = [] of String
    attribute images : Array(String) = [] of String
    attribute playlists : Array(String) = [] of String, es_type: "keyword"

    # Association
    ###############################################################################################
    belongs_to Zone, foreign_key: "parent_id", association_name: "parent"

    has_many(
      child_class: Zone,
      collection_name: "children",
      foreign_key: "parent_id",
      dependent: :destroy
    )

    has_many(
      child_class: TriggerInstance,
      collection_name: "trigger_instances",
      foreign_key: "zone_id",
      dependent: :destroy,
    )

    # Metadata belonging to this zone
    has_many(
      child_class: Metadata,
      collection_name: "metadata_and_versions",
      foreign_key: "parent_id",
      dependent: :destroy
    )

    # Encrypted yaml settings
    has_many(
      child_class: Settings,
      collection_name: "settings_and_versions",
      foreign_key: "parent_id",
      dependent: :destroy
    )

    def root_zone_id : String
      raise "zone model not persisted and has no parent" unless persisted? || self.parent_id.presence
      return self.id.as(String) unless self.parent_id.presence

      query = %[
        WITH RECURSIVE zone_hierarchy AS (
            SELECT id, parent_id
            FROM zone
            WHERE id = $1

            UNION ALL
            SELECT z.id, z.parent_id
            FROM zone z
            INNER JOIN zone_hierarchy zh ON z.id = zh.parent_id
        )
        SELECT id
        FROM zone_hierarchy
        WHERE parent_id IS NULL OR parent_id = '';
      ]

      PgORM::Database.connection(&.query_one?(query, self.parent_id, &.read(String))).as(String)
    end

    def root_zone
      return self unless self.parent_id.presence
      Zone.find!(root_zone_id)
    end

    # Validation
    ###############################################################################################

    validates :name, presence: true
    ensure_unique :name do |name|
      name.strip
    end

    # Callbacks
    ###############################################################################################

    before_destroy :remove_zone

    before_save :check_triggers

    after_save :update_triggers

    # Removes self from ControlSystems
    protected def remove_zone
      self.systems.try &.each do |cs|
        zones = cs.zones
        if zones
          cs.zones = zones.reject(self.id)

          version = cs.version
          cs.version = version + 1 if version

          cs.save!
        end
      end
    end

    private property remove_triggers : Array(String) { [] of String }
    private property add_triggers : Array(String) { [] of String }
    private property? update_systems = false

    protected def check_triggers
      if triggers_changed?
        previous = self.triggers_was || [] of String
        current = self.triggers

        self.remove_triggers = previous - current
        self.add_triggers = current - previous

        self.update_systems = !remove_triggers.empty? || !add_triggers.empty?
      else
        self.update_systems = false
      end
    end

    protected def update_triggers
      return unless update_systems?

      # Remove TriggerInstances
      unless remove_triggers.empty?
        self.trigger_instances.each do |trig|
          trig.destroy if remove_triggers.includes?(trig.trigger_id)
        end
      end

      # Add TriggerInstances
      unless add_triggers.empty?
        self.systems.try &.each do |sys|
          add_triggers.each do |trig_id|
            inst = TriggerInstance.new(trigger_id: trig_id, zone_id: self.id)
            inst.control_system = sys
            inst.save
          end
        end
      end
    end

    # Queries
    ###########################################################################

    def settings_hierarchy : Array(Settings)
      settings
    end

    def self.with_tag(tag : String)
      Zone.where("$1 = Any(tags)", tag)
    end

    # TODO: Implement multiple element `contains` in crystal-rethinkdb
    # def self.with_tag(tags : Enumerable(String))
    #   Zone.raw_query do |q|
    #     q
    #       .table(PlaceOS::Model::Zone.table_name)
    #       .filter &.["tags"].contains(*tags)
    #   end
    # end

    # Find systems
    def systems
      ControlSystem.by_zone_id(self.id)
    end

    # Looks up the triggers attached to the zone
    def trigger_data : Array(Trigger)
      if self.triggers.empty?
        [] of Trigger
      else
        Trigger.find_all(self.triggers).to_a
      end
    end
  end
end
