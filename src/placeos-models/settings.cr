require "time"

require "./base/model"
require "./error"
require "./utilities/encryption"
require "./utilities/last_modified"
require "./utilities/versions"

require "./control_system"
require "./driver"
require "./module"
require "./zone"

module PlaceOS::Model
  class Settings < ModelBase
    include PlaceOS::Model::Timestamps
    include Utilities::LastModified
    include Utilities::Versions

    table :sets

    # TODO: Statically ensure a single `parent_id` exists on the table

    attribute encryption_level : Encryption::Level = Encryption::Level::None, converter: Enum::ValueConverter(PlaceOS::Encryption::Level), es_type: "integer"

    attribute settings_string : String = "{}"
    attribute keys : Array(String) = [] of String, es_type: "text"

    # Possible parent documents
    enum ParentType
      ControlSystem
      Driver
      Module
      Zone

      def self.from_id?(id : String?) : ParentType?
        return if id.nil?

        case id
        when .starts_with?(Model::ControlSystem.table_name) then ControlSystem
        when .starts_with?(Model::Driver.table_name)        then Driver
        when .starts_with?(Model::Module.table_name)        then Module
        when .starts_with?(Model::Zone.table_name)          then Zone
        end
      end
    end

    attribute parent_type : ParentType, converter: Enum::ValueConverter(PlaceOS::Model::Settings::ParentType), es_type: "keyword"

    # Association
    ###############################################################################################

    attribute parent_id : String?, es_type: "keyword"
    attribute settings_id : String? = nil

    belongs_to ControlSystem, foreign_key: "parent_id"
    belongs_to Driver, foreign_key: "parent_id"
    belongs_to Module, foreign_key: "parent_id", association_name: "mod"
    belongs_to Zone, foreign_key: "parent_id"

    # Validation
    ###############################################################################################

    validates :encryption_level, presence: true
    validates :parent_id, presence: true
    validates :parent_type, presence: true

    # Ensure `settings_string` is valid
    validate ->(this : Settings) do
      if this.settings_string_changed?
        unencrypted = Encryption.is_encrypted?(this.settings_string) ? this.decrypt : this.settings_string
        unless unencrypted.strip.empty?
          begin
            Hash(String, YAML::Any).from_yaml(unencrypted)
          rescue
            this.validation_error(:settings_string, "is not a valid JSON or YAML object")
          end
        end
      end
    end

    # Parent accessor
    ###############################################################################################

    # Retrieve the parent relation
    #
    def parent
      return nil unless p_id = parent_id

      case ParentType.from_id?(p_id)
      in Zone          then Zone.find(p_id)
      in ControlSystem then ControlSystem.find(p_id)
      in Driver        then Driver.find(p_id)
      in Module        then Module.find(p_id)
      in Nil           then nil
      end
    end

    def parent=(parent : Union(Zone, ControlSystem, Driver, Module))
      case parent
      in ControlSystem then self.control_system = parent
      in Driver        then self.driver = parent
      in Module        then self.mod = parent
      in Zone          then self.zone = parent
      end
    end

    # Callbacks
    ###########################################################################

    before_save :parse_parent_type

    before_save :build_keys

    before_save :encrypt_settings

    # Parse `parent_id` and set the `parent_type` of the `Settings`
    #
    protected def parse_parent_type
      if (type = ParentType.from_id?(parent_id))
        self.parent_type = type
      else
        raise Model::Error.new("Failed to parse Settings' parent type from #{parent_id}")
      end
    rescue e : NilAssertionError
      raise Model::Error::NoParent.new("Missing required parent for Settings<#{id}>")
    end

    # Generate keys for settings object
    #
    protected def build_keys : Array(String)
      unencrypted = Encryption.is_encrypted?(settings_string) ? decrypt : settings_string
      self.keys = YAML.parse(unencrypted).as_h?.try(&.keys.map(&.to_s)) || [] of String
    end

    # Generate a version upon save of a master Settings
    #
    protected def create_version(version : self) : self
      version.settings_string = encrypt(settings_string)
      version
    end

    # Queries
    ###########################################################################

    # Get `Settings` for given parent id/s
    #
    def self.for_parent(parent_ids : String | Array(String), &) : Array(self)
      master_settings_query do |q|
        q.where({parent_id: parent_ids})
      end.sort_by! do |setting|
        # Reversed
        -1 * setting.encryption_level.value
      end
    end

    # :ditto:
    def self.for_parent(parent_ids : String | Array(String)) : Array(self)
      for_parent(parent_ids, &.itself)
    end

    # Query all settings under `parent_id`
    #
    def self.query(ids : String | Array(String))
      Settings.find_all(ids.is_a?(Array) ? ids : [ids])
    end

    # Locate the modules that will be affected by the change of this setting
    #
    def dependent_modules : Array(Model::Module)
      model_id = parent_id
      model_type = parent_type
      return [] of Module if model_id.nil? || model_type.nil?

      case model_type
      in .module?
        [Module.find!(model_id)]
      in .driver?
        Module.by_driver_id(model_id).to_a
      in .control_system?
        Module
          .in_control_system(model_id)
          .select(&.role.logic?)
          .to_a
      in .zone?
        Module
          .in_zone(model_id)
          .select(&.role.logic?)
          .to_a
      end
    end

    # Encryption
    ###########################################################################

    protected def encrypt(string : String)
      raise Model::Error::NoParent.new if (encryption_id = parent_id).nil?

      Encryption.encrypt(string, level: encryption_level, id: encryption_id)
    end

    # Encrypts all settings.
    #
    protected def encrypt_settings
      self.settings_string = encrypt(settings_string)
    end

    # Encrypt in place
    #
    def encrypt!
      encrypt_settings
      self
    end

    # Decrypts the model's setting string
    #
    protected def decrypt
      raise Model::Error::NoParent.new if (encryption_id = parent_id).nil?

      Encryption.decrypt(string: settings_string, level: encryption_level, id: encryption_id)
    end

    # Decrypts the model's settings string dependent on user privileges
    #
    def decrypt_for!(user)
      self.settings_string = decrypt_for(user)
      self
    end

    # Decrypts (if user has correct privilege) and returns the settings string
    #
    def decrypt_for(user) : String
      raise Model::Error::NoParent.new unless (encryption_id = parent_id)

      Encryption.decrypt_for(user: user, string: settings_string, level: encryption_level, id: encryption_id)
    end

    # Settings Methods
    ###########################################################################

    # Decrypt and pick off the setting
    #
    def get_setting_for?(user, setting) : YAML::Any?
      Settings.get_setting_for(user, setting, [self])
    end

    # Check if top-level settings key present for the supplied user
    #
    def has_key_for?(user, key)
      has_key = keys.try(&.includes?(key))
      has_privilege = Settings.has_privilege?(user, encryption_level)
      has_key && has_privilege
    end

    # Look up a settings key, if it exists and the user has the correct privilege
    #
    def self.get_setting_for?(user : Model::User, key : String, settings : Array(Settings) = [] of Settings) : YAML::Any?
      # First check if key present, then deserialise
      if settings.any?(&.has_key_for?(user, key))
        settings
          # Sort on privilege
          .sort_by(&.encryption_level)
          # Attain (if exists) setting for given key
          .compact_map(&.any[key]?)
          # Get the lowest privilege setting
          .first
      end
    end

    # Decrypts settings, encodes as a json object
    #
    def settings_json
      any.to_json
    end

    # Decrypts settings for a user, merges into single JSON object
    #
    def any(user : User) : Hash(YAML::Any, YAML::Any)?
      decrypt_for(user).try { |s| Settings.parse_settings_string(s) }
    end

    # Decrypts settings, merges into single JSON object
    #
    def any : Hash(YAML::Any, YAML::Any)
      Settings.parse_settings_string(decrypt)
    end

    protected def self.parse_settings_string(settings_string : String)
      settings_string = settings_string.strip
      if settings_string.empty?
        {} of YAML::Any => YAML::Any
      else
        YAML.parse(settings_string).as_h
      end
    rescue e
      raise Model::Error.new("Failed to parse YAML settings: #{settings_string}", cause: e)
    end

    # Helpers
    ###########################################################################

    def self.has_privilege?(user : User, encryption_level : Encryption::Level)
      case encryption_level
      in .none?          then true
      in .support?       then user.is_admin? || user.is_support?
      in .admin?         then user.is_admin?
      in .never_display? then false
      end
    end

    # Determine if setting_string is encrypted
    #
    def is_encrypted? : Bool
      Encryption.is_encrypted?(settings_string)
    end
  end
end
