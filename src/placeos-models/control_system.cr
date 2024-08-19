require "time"
require "uri"
require "future"

require "./converter/time_location"

require "./base/model"
require "./settings"
require "./email"
require "./utilities/settings_helper"
require "./utilities/metadata_helper"
require "./playlist"

module PlaceOS::Model
  class ControlSystem < ModelBase
    include PlaceOS::Model::Timestamps
    include Utilities::SettingsHelper
    include Utilities::MetadataHelper
    include Playlist::Checker

    table :sys

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""

    # Room search meta-data
    # Building + Level are both filtered using zones
    attribute features : Set(String) = ->{ Set(String).new }
    attribute email : Email?, converter: PlaceOS::Model::EmailConverter
    attribute bookable : Bool = false
    attribute public : Bool = false
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

    # Systems as digital signage displays
    # playlists can be assigned directly to displays or to zones
    # playlists in zones will only be loaded if they have matching orientations
    attribute orientation : Playlist::Orientation = Playlist::Orientation::Unspecified, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::Playlist::Orientation)
    attribute playlists : Array(String) = [] of String, es_type: "keyword"
    attribute signage : Bool = false

    # Associations
    ###############################################################################################

    # Encrypted yaml settings, with metadata
    has_many(
      child_class: Settings,
      collection_name: "settings_and_versions",
      foreign_key: "parent_id",
      dependent: :destroy
    )

    # Metadata belonging to this control_system
    has_many(
      child_class: Metadata,
      collection_name: "metadata_and_versions",
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
      ControlSystem.where("$1 = Any(zones)", id)
    end

    @[Deprecated("Use `by_zone_id`")]
    def self.in_zone(id)
      self.by_zone_id(id)
    end

    def self.by_module_id(id)
      ControlSystem.where("$1 = Any(modules)", id)
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
      hierarchy = settings

      # Zone Settings
      zone_models = Model::Zone.find_all(self.zones).to_a
      # Merge by highest associated zone
      self.zones.reverse_each do |zone_id|
        next if (zone = zone_models.find &.id.==(zone_id)).nil?

        begin
          hierarchy.concat(zone.settings)
        rescue error
          Log.warn(exception: error) { "failed to merge zone #{zone_id} settings" }
        end
      end

      hierarchy.compact
    end

    # Callbacks
    ###############################################################################################

    before_destroy :cleanup_modules

    before_save :check_zones

    before_save :check_modules

    after_save :update_triggers

    # Internal modules
    private IGNORED_MODULES = ["__Triggers__"]

    # Remove Modules not associated with any other systems
    # NOTE: Includes compulsory associated Logic Modules
    def cleanup_modules
      return if self.modules.empty?

      modules_with_single_occurrence.map do |m|
        future { m.destroy }
      end.each(&.get)
    end

    def modules_with_single_occurrence : Array(Module)
      Module.where(%[
        id IN (
        SELECT module
        FROM (
            SELECT UNNEST(modules) AS module
            FROM sys
        ) AS module_list
        WHERE module IN ('#{self.modules.join("', '")}')
        GROUP BY module
        HAVING COUNT(*) = 1)
      ]).to_a
    end

    # ensure all the modules are valid and exist
    def check_modules
      sql_query = %[
        WITH input_ids AS (
          SELECT unnest(#{Associations.format_list_for_postgres(self.modules)}) AS id
        )

        SELECT ARRAY_AGG(input_ids.id)
        FROM input_ids
        LEFT JOIN mod ON input_ids.id = mod.id
        WHERE mod.id IS NULL;
      ]

      remove_mods = ::PgORM::Database.connection do |conn|
        conn.query_one(sql_query, &.read(Array(String)?))
      end

      if remove_mods && !remove_mods.empty?
        self.modules = self.modules - remove_mods
      end
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
        self.version = ControlSystem.find(id).version
      end
    end

    def self.add_module(control_system_id : String, module_id : String)
      response = ::PgORM::Database.connection do |db|
        db.exec(<<-SQL, control_system_id, [module_id])
          update #{ControlSystem.table_name} set modules = modules || $2, version = version + 1 where id = $1
        SQL
      end

      response.rows_affected > 0
    end

    # Removes the module from the system and deletes it if not used elsewhere
    #
    def remove_module(module_id : String)
      mod = Module.find?(module_id)
      if self.modules.includes?(module_id) && ControlSystem.remove_module(id.as(String), module_id)
        self.modules_will_change!
        self.modules.delete(module_id)
        unless mod.nil?
          # Remove the module from the control system's features
          self.features_will_change!
          self.features.delete(mod.resolved_name)
          self.features.delete(mod.name)
        end
        self.version = ControlSystem.find(id).version
      end
    end

    def self.remove_module(control_system_id : String, module_id : String)
      response = ::PgORM::Database.connection do |db|
        db.exec(<<-SQL, control_system_id, [module_id])
          update #{ControlSystem.table_name} set modules=(select array(select unnest(modules) except select unnest($2::text[]))), version = version + 1 where id = $1
        SQL
      end

      return false unless response.rows_affected > 0

      # Keep if any other ControlSystem is using the module
      still_in_use = ControlSystem.by_module_id(module_id).any? do |sys|
        sys.id != control_system_id
      end

      Module.find?(module_id).try(&.destroy) unless still_in_use

      Log.debug { {
        message:           "module removed from system #{still_in_use ? "still in use" : "deleted as not in any other systems"}",
        module_id:         module_id,
        control_system_id: control_system_id,
      } }

      true
    end

    # Playlist management
    # ===================

    def playlists_last_updated(playlists : Hash(String, Array(String)) = all_playlists) : Time
      playlist_ids = playlists.values.flatten.uniq!
      if !playlist_ids.empty?
        rev_updated_at = Playlist::Revision.where(playlist_id: playlist_ids).order(updated_at: :desc).limit(1).to_a.first?.try(&.updated_at)
      end
      trig_updated_at = TriggerInstance
        .where(control_system_id: self.id.as(String))
        .where("cardinality(playlists) > ?", 0)
        .order(updated_at: :desc)
        .limit(1).to_a.first?.try(&.updated_at)

      [rev_updated_at, trig_updated_at, self.updated_at].compact.max
    end

    def self.with_playlists(ids : Enumerable(String))
      ControlSystem.where("playlists @> #{Associations.format_list_for_postgres(ids)}")
    end

    def all_playlists : Hash(String, Array(String))
      # find all the zones and triggers with playlists configured
      # then construct a hash
      sys_id = self.id.as(String)
      sql_query = %[
        WITH zone_ids AS (
          SELECT UNNEST(zones) as zone_id
          FROM sys
          WHERE id = $1
        ),
        zone_playlists AS (
          SELECT z.id, z.playlists
          FROM zone z
          INNER JOIN zone_ids zi ON z.id = zi.zone_id
          WHERE cardinality(z.playlists) > 0
        ),
        trig_playlists AS (
          SELECT t.id, t.playlists
          FROM trig t
          WHERE t.control_system_id = $1 AND cardinality(t.playlists) > 0
        )

        SELECT id, playlists FROM zone_playlists
        UNION ALL
        SELECT id, playlists FROM trig_playlists;
      ]

      playlists = {
        sys_id => self.playlists,
      }
      ::PgORM::Database.connection do |conn|
        conn.query(sql_query, args: [sys_id]) do |rs|
          while rs.move_next
            playlists[rs.read(String)] = rs.read(Array(String))
          end
        end
      end

      playlists
    end
  end
end
