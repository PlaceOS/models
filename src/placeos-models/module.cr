require "future"
require "uri"

require "./base/model"
require "./driver"
require "./edge"
require "./settings"
require "./utilities/settings_helper"

module PlaceOS::Model
  class Module < ModelBase
    include PlaceOS::Model::Timestamps
    include Utilities::SettingsHelper

    table :mod

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

    # Runtime Error Indicators
    attribute has_runtime_error : Bool = false
    attribute error_timestamp : Time? = nil, converter: Time::EpochConverter, type: "integer", format: "Int64"

    # Associations
    ###############################################################################################

    # Control System the _logic_ module may be assigned to
    belongs_to ControlSystem, foreign_key: "control_system_id"

    # The binary the module is to run on
    belongs_to Driver, foreign_key: "driver_id", presence: true

    # The edge node the module may be assigned to
    belongs_to Edge, foreign_key: "edge_id"

    # Encrypted yaml settings, with metadata
    has_many(
      child_class: Settings,
      collection_name: "settings_and_versions",
      foreign_key: "parent_id",
      dependent: :destroy
    )

    # Validation
    ###############################################################################################

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

      # URI presence
      unless self.uri.presence
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

      # No blank IP
      self.validation_error(:ip, "cannot be blank") unless self.ip.presence
      # Port in valid range
      self.validation_error(:port, "is invalid") unless (1..65_535).includes?(self.port)

      self.tls = false if self.udp

      unless Validation.valid_uri?("http://#{ip}:#{port}/")
        validation_error(:ip, "address, hostname or port are invalid")
      end
    end

    # Queries
    ###############################################################################################

    # Finds the systems for which this module is in use
    def systems
      ControlSystem.by_module_id(self.id)
    end

    # Find `Module`s allocated to an `Edge`
    #
    def self.on_edge(edge_id : String)
      Module.where(edge_id: edge_id)
    end

    # Fetch `Module`s who have a direct parent `ControlSystem`
    #
    def self.logic_for(control_system_id : String)
      Module.where(control_system_id: [control_system_id])
    end

    def self.in_control_system(control_system_id : String)
      Module.find_all_by_sql(<<-SQL, args: [control_system_id])
        select distinct * from "#{Module.table_name}" where id in (select unnest(modules) from "#{ControlSystem.table_name}" where id = $1)
      SQL
    end

    def self.in_zone(zone_id : String)
      Module.find_all_by_sql(<<-SQL, args: [zone_id])
        select distinct * from "#{Module.table_name}" where id in (select unnest(modules) from "#{ControlSystem.table_name}" where $1 = ANY(zones))
      SQL
    end

    # Collect Settings ordered by hierarchy
    #
    # Module > (Control System > Zones) > Driver
    def settings_hierarchy : Array(Settings)
      # Accumulate settings, starting with the Module's
      hierarchy = settings

      if role.logic?
        cs = self.control_system
        raise Model::Error::NoParent.new("Missing control system: module_id=#{@id} control_system_id=#{@control_system_id}") if cs.nil?
        # Control System < Zone Settings
        hierarchy.concat(cs.settings_hierarchy)
      end

      # Driver Settings
      hierarchy.concat(self.driver.as(Model::Driver).settings)

      hierarchy.compact
    end

    # Merge settings hierarchy to JSON
    #
    # [Read more](https://docs.google.com/document/d/1qAbdaYAl5f9rYU6xuT_3TXpnjCqsqeBezhDB-TbHvJA/edit#heading=h.ntoecut6aqkj)
    def merge_settings
      # Merge all settings, serialise to JSON
      settings_hierarchy.reverse!.reduce({} of YAML::Any => YAML::Any) do |merged, setting|
        begin
          merged.merge!(setting.any)
        rescue error
          Log.warn(exception: error) { "failed to merge settings: #{setting.inspect}" }
        end
        merged
      end.to_json
    end

    # Callbacks
    ###############################################################################################

    # Add the Logic module directly to parent ControlSystem
    after_create :add_logic_module

    # Remove the module from associated (if any) ControlSystem
    before_destroy :remove_module

    # Ensure fields inherited from Driver are set correctly
    before_save :set_name_and_role

    # NOTE: Temporary while `edge` feature developed
    before_create :set_edge_hint

    # Logic modules are automatically added to the ControlSystem
    #
    protected def add_logic_module
      return unless (cs = self.control_system)

      cs.modules_will_change!
      cs.modules = cs.modules << self.id.as(String)
      cs.version = cs.version + 1
      cs.save!
    end

    # Remove the module from associated ControlSystem
    #
    protected def remove_module
      mod_id = self.id.as(String)

      ControlSystem.where("$1 = ANY(modules)", mod_id)
        .map do |sys|
          sys.remove_module(mod_id)
          sys.save!
        end
    end

    # Set the name/role from the associated Driver
    #
    protected def set_name_and_role
      driver_ref = driver
      raise Model::Error::NoParent.new("Module<#{id}> missing parent Driver") unless driver_ref

      self.role = driver_ref.role
      self.name = driver_ref.module_name

      unless self.running
        has_runtime_error = false
        error_timestamp = nil
      end
    end

    private EDGE_HINT = "-edge"

    protected def set_edge_hint
      if on_edge?
        self.new_record = true
        @id = Utilities::IdGenerator.next(self) + EDGE_HINT
      end
    end

    # Overridden attribute accessors
    ###############################################################################################

    # Set driver and role
    def driver=(driver : Driver)
      previous_def(driver)
      self.role = driver.role
      self.name = driver.module_name
    end

    # Getter for the module's host
    #
    def hostname
      case role
      in .ssh?, .device?
        self.ip
      in .service?, .websocket?
        uri = self.uri || self.driver.try &.default_uri
        uri.try(&->URI.parse(String)).try(&.host)
      in .logic?
        # No hostname for Logic module
        nil
      in Nil
        nil
      end
    end

    # Setter for Device module ip
    def hostname=(host : String)
      # TODO: resolve hostname?
      @ip = host
    end

    # Use custom name if it is defined and non-empty, otherwise use module name
    #
    def resolved_name : String
      custom = self.custom_name.presence
      custom.nil? ? self.name : custom
    end

    def resolved_name_changed? : Bool
      self.custom_name_changed? || self.name_changed?
    end

    # Edge Helpers
    ###############################################################################################

    # Whether or not module is an edge module
    #
    def on_edge?
      !self.edge_id.nil?
    end

    # Hint in the model id whether the module is an edge module
    #
    def self.has_edge_hint?(module_id : String)
      module_id.ends_with? EDGE_HINT
    end
  end
end
