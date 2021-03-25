require "rethinkdb-orm"
require "future"
require "uri"

require "./base/model"
require "./driver"
require "./edge"
require "./settings"
require "./utilities/settings_helper"

module PlaceOS::Model
  class Module < ModelBase
    include RethinkORM::Timestamps
    include SettingsHelper

    table :mod

    # The classes/files that this module requires to execute
    belongs_to Driver, foreign_key: "driver_id", presence: true

    belongs_to ControlSystem, foreign_key: "control_system_id"

    belongs_to Edge, foreign_key: "edge_id"

    attribute ip : String = "", es_type: "text"
    attribute port : Int32 = 0
    attribute tls : Bool = false
    attribute udp : Bool = false
    attribute makebreak : Bool = false

    # HTTP Service module
    attribute uri : String = "", es_type: "keyword"

    # Module name
    attribute name : String, es_subfield: "keyword", mass_assignment: false

    # Custom module names (in addition to what is defined in the driver)
    attribute custom_name : String?

    # Encrypted yaml settings, with metadata
    has_many(
      child_class: Settings,
      collection_name: "settings",
      foreign_key: "parent_id",
      dependent: :destroy
    )

    # Cache the module's driver role locally for load order
    attribute role : Driver::Role, es_type: "integer", converter: Enum::ValueConverter(PlaceOS::Model::Driver::Role)

    # Connected state in model so we can filter and search on it
    attribute connected : Bool = true
    attribute running : Bool = false
    attribute notes : String = ""

    # Don't include this module in statistics or disconnected searches
    # Might be a device that commonly goes offline (like a PC or Display that only supports Wake on Lan)
    attribute ignore_connected : Bool = false
    attribute ignore_startstop : Bool = false

    # Add the Logic module directly to parent ControlSystem
    after_create :add_logic_module

    # Remove the module from associated (if any) ControlSystem
    before_destroy :remove_module

    # Ensure fields inherited from Driver are set correctly
    before_save :set_name_and_role

    # NOTE: Temporary while `edge` feature developed
    before_create :set_edge_hint

    # Finds the systems for which this module is in use
    def systems
      ControlSystem.by_module_id(self.id)
    end

    # Find `Module`s allocated to an `Edge`
    #
    def self.on_edge(edge_id : String)
      Module.get_all([edge_id], index: :edge_id)
    end

    # Fetch `Module`s who have a direct parent `ControlSystem`
    #
    def self.logic_for(control_system_id : String)
      Module.get_all([control_system_id], index: :control_system_id)
    end

    def self.in_control_system(control_system_id : String)
      Module.raw_query do |q|
        q
          .table(PlaceOS::Model::ControlSystem.table_name)
          # Find the control system
          .get(control_system_id)["modules"]
          # Find the module ids for the control systems
          .map { |id| q.table(PlaceOS::Model::Module.table_name).get(id) }
          # Return all modules located
          .filter(&.has_fields("id"))
          # Unique module ids
          .distinct
      end
    end

    def self.in_zone(zone_id : String)
      Module.raw_query do |q|
        q
          .table(PlaceOS::Model::ControlSystem.table_name)
          # Find control systems that have the zone
          .filter(&.["zones"].contains(zone_id))
          # Find the module ids for the control systems
          .concat_map { |sys|
            sys["modules"].map { |id| q.table(PlaceOS::Model::Module.table_name).get(id) }
          }
          # Return all modules located
          .filter(&.has_fields("id"))
          # Unique module ids
          .distinct
      end
    end

    # Collect Settings ordered by hierarchy
    #
    # Module > (Control System > Zones) > Driver
    def settings_hierarchy
      # Accumulate settings, starting with the Module's
      settings = master_settings

      if role.logic?
        cs = self.control_system
        raise "Missing control system: module_id=#{@id} control_system_id=#{@control_system_id}" if cs.nil?
        # Control System < Zone Settings
        settings.concat(cs.settings_hierarchy)
      end

      # Driver Settings
      settings.concat(self.driver.as(Model::Driver).master_settings)

      settings.compact
    end

    # Merge settings hierarchy to JSON
    #
    # [Read more](https://docs.google.com/document/d/1qAbdaYAl5f9rYU6xuT_3TXpnjCqsqeBezhDB-TbHvJA/edit#heading=h.ntoecut6aqkj)
    def merge_settings
      # Merge all settings, serialise to JSON
      settings_hierarchy.reverse!.reduce({} of YAML::Any => YAML::Any) do |merged, setting|
        merged.merge!(setting.any)
      end.to_json
    end

    # Whether or not module is an edge module
    #
    def on_edge?
      !self.edge_id.nil?
    end

    private EDGE_HINT = "-edge"

    protected def set_edge_hint
      if on_edge?
        self._new_flag = true
        @id = RethinkORM::IdGenerator.next(self) + EDGE_HINT
      end
    end

    # Hint in the model id whether the module is an edge module
    #
    def self.has_edge_hint?(module_id : String)
      module_id.ends_with? EDGE_HINT
    end

    # Getter for the module's host
    #
    def hostname
      return if (_role = role).nil?

      case _role
      in .ssh?, .device?
        self.ip
      in .service?, .websocket?
        uri = self.uri || self.driver.try &.default_uri
        uri.try(&->URI.parse(String)).try(&.host)
      in .logic?
        # No hostname for Logic module
        nil
      end
    end

    # Setter for Device module ip
    def hostname=(host : String)
      # TODO: resolve hostname?
      @ip = host
    end

    # Set driver and role
    def driver=(driver : Driver)
      previous_def(driver)
      self.role = driver.role
      self.name = driver.module_name
    end

    # Use custom name if it is defined and non-empty, otherwise use module name
    #
    def resolved_name : String
      custom = self.custom_name

      custom.nil? || custom.empty? ? self.name : custom
    end

    validate ->(this : Module) {
      driver = this.driver
      role = driver.try(&.role)
      return if driver.nil? || role.nil?

      case role
      in .service?, .websocket?
        this.validate_service_module(driver.role)
      in .logic?
        this.validate_logic_module
      in .device?, .ssh?
        this.validate_device_module
      end

      this.validate_no_parent_system unless this.role.logic?
    }

    protected def has_control?
      !self.control_system_id.presence.nil?
    end

    protected def validate_no_parent_system
      self.validation_error(:control_system, "should not be associated for #{self.role} modules") if has_control?
    end

    protected def validate_logic_module
      self.tls = false
      self.udp = false

      self.connected = true # Logic modules are connectionless
      self.role = Driver::Role::Logic
      self.validation_error(:control_system, "must be associated for logic modules") unless has_control?
      self.validation_error(:edge, "logic module cannot be allocated to an edge") if self.on_edge?
    end

    protected def validate_service_module(driver_role)
      self.role = driver_role
      self.udp = false

      return if (driver = self.driver).nil?

      unless (default_uri = driver.default_uri.presence).nil?
        self.uri ||= default_uri
      end

      if self.uri.blank?
        self.validation_error(:uri, "not present")
        return
      end

      # Set secure transport flag if URI defines `https` protocol
      self.tls = URI.parse(self.uri).scheme == "https"

      self.validation_error(:uri, "is an invalid URI") unless Validation.valid_uri?(uri)
    end

    protected def validate_device_module
      return if (driver = self.driver).nil?

      self.role = driver.role
      self.port ||= (driver.default_port || 0)
      self.tls = !udp

      # No blank IP
      validation_error(:ip, "cannot be blank") if ip.blank?
      # Port in valid range
      validation_error(:port, "is invalid") unless (1..65_535).includes?(port)

      unless Validation.valid_uri?("http://#{ip}:#{port}/")
        validation_error(:ip, "address, hostname or port are invalid")
      end
    end

    # Logic modules are automatically added to the ControlSystem
    #
    protected def add_logic_module
      return unless (cs = self.control_system)

      modules = cs.modules.as(Array(String))
      cs.modules = modules << self.id.as(String)
      cs.version = cs.version.as(Int32) + 1
      cs.save!
    end

    # Remove the module from associated ControlSystem
    #
    protected def remove_module
      mod_id = self.id.as(String)

      ControlSystem
        .raw_query(&.table(ControlSystem.table_name).filter(&.["modules"].contains(mod_id)))
        .map do |sys|
          sys.remove_module(mod_id)
          # The `ControlSystem` will regenerate `features`
          future {
            sys.save!
          }
        end.each &.get
    end

    # Set the name/role from the associated Driver
    #
    protected def set_name_and_role
      driver_ref = driver
      raise NoParentError.new("Module<#{id}> missing parent Driver") unless driver_ref

      self.role = driver_ref.role
      self.name = driver_ref.module_name
    end
  end
end
