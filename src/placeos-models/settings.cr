require "rethinkdb-orm"
require "time"

require "./base/model"
require "./error"
require "./utilities/encryption"

require "./control_system"
require "./driver"
require "./module"
require "./zone"

module PlaceOS::Model
  # TODO: Statically ensure a single parent id exists on the table
  class Settings < ModelBase
    include RethinkORM::Timestamps

    table :sets

    attribute parent_id : String?, es_type: "keyword"
    attribute settings_id : String? = nil

    secondary_index :parent_id
    secondary_index :settings_id

    attribute encryption_level : Encryption::Level = Encryption::Level::None, converter: Enum::ValueConverter(PlaceOS::Encryption::Level)

    attribute settings_string : String = "{}"
    attribute keys : Array(String) = [] of String, es_type: "text"

    belongs_to ControlSystem, foreign_key: "parent_id"
    belongs_to Driver, foreign_key: "parent_id"
    belongs_to Module, foreign_key: "parent_id", association_name: "mod"
    belongs_to Zone, foreign_key: "parent_id"

    # Settings self-referential entity relationship acts as a 2-level tree
    has_many(
      child_class: Settings,
      collection_name: "settings",
      foreign_key: "settings_id",
      dependent: :destroy
    )

    validates :encryption_level, presence: true
    validates :parent_id, presence: true
    validates :parent_type, presence: true

    # Ensure `settings_string` is valid
    validate ->(this : Settings) {
      if this.settings_string_changed?
        unencrypted = Encryption.is_encrypted?(this.settings_string) ? this.decrypt : this.settings_string
        begin
          YAML.parse(unencrypted) rescue JSON.parse(unencrypted)
        rescue
          this.validation_error(:settings_string, "is invalid JSON/YAML")
        end
      end
    }

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

    attribute parent_type : ParentType

    # Callbacks
    ###########################################################################

    before_save :parse_parent_type
    before_save :build_keys
    before_save :encrypt_settings
    after_save :create_version

    # Parse `parent_id` and set the `parent_type` of the `Settings`
    #
    def parse_parent_type
      if (type = ParentType.from_id?(parent_id))
        self.parent_type = type
      else
        raise Error.new("Failed to parse Settings' parent type from #{parent_id}")
      end
    rescue e : NilAssertionError
      raise NoParentError.new
    end

    # Generate keys for settings object
    #
    def build_keys : Array(String)
      unencrypted = Encryption.is_encrypted?(settings_string) ? decrypt : settings_string
      self.keys = YAML.parse(unencrypted).as_h?.try(&.keys.map(&.to_s)) || [] of String
    end

    # Generate a version upon save of a master Settings
    #
    def create_version
      return if is_version?

      old_settings = encrypt(settings_string)
      attrs = attributes_tuple.merge({id: nil, created_at: nil, updated_at: nil, settings_string: old_settings})
      version = Settings.new(**attrs)
      version.settings_id = self.id
      version.save!
    end

    # Queries
    ###########################################################################

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

    # Get version history
    #
    # Versions are in descending order of creation
    def history(offset : Int32 = 0, limit : Int32 = 10)
      slice_start = offset
      slice_end = offset + limit

      versions = Settings.raw_query do |r|
        r
          .table(Settings.table_name)
          .get_all([parent_id.as(String)], index: :parent_id)
          .filter({settings_id: id.as(String)})
          .order_by(r.desc(:created_at)).slice(slice_start, slice_end)
      end

      versions.to_a
    end

    # Get settings for given parent id/s
    #
    def self.for_parent(parent_ids : String | Array(String)) : Array(Settings)
      master_settings_query(parent_ids) { |q| q }
    end

    # Query on master settings associated with ids
    #
    def self.master_settings_query(ids : String | Array(String))
      # Get documents where the settings_id does not exist, i.e. is the master
      cursor = query(ids) do |q|
        yield q.filter &.has_fields(:settings_id).not
      end

      cursor
        .to_a
        .sort_by!(&.encryption_level.as(Encryption::Level))
        .reverse!
    end

    # Query all settings under parent_id
    #
    def self.query(ids : String | Array(String))
      ids = ids.is_a?(Array) ? ids : [ids]
      Settings.raw_query do |q|
        yield q.table(Settings.table_name).get_all(ids, index: :parent_id)
      end
    end

    # Encryption methods
    ###########################################################################

    protected def encrypt(string : String)
      raise NoParentError.new if (encryption_id = parent_id).nil?

      Encryption.encrypt(string, level: encryption_level, id: encryption_id)
    end

    # Encrypts all settings.
    #
    def encrypt_settings
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
    def decrypt
      raise NoParentError.new if (encryption_id = parent_id).nil?

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
      raise NoParentError.new unless (encryption_id = parent_id)

      Encryption.decrypt_for(user: user, string: settings_string, level: encryption_level, id: encryption_id)
    end

    # Retrieve the parent relation
    #
    def parent
      [
        self.control_system,
        self.driver,
        self.mod,
        self.zone,
      ].compact.first?
    end

    def parent=(parent : Union(Zone, ControlSystem, Driver, Module))
      case parent
      in ControlSystem then self.control_system = parent
      in Driver        then self.driver = parent
      in Module        then self.mod = parent
      in Zone          then self.zone = parent
      end
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

    # Look up a settings key, if it exists and the user has the correct privilege
    #
    def self.get_setting_for?(user : Model::User, key : String, settings : Array(Settings) = [] of Settings) : YAML::Any?
      # First check if key present, then deserialise
      if settings.any?(&.has_key_for?(user, key))
        settings
          # Sort on privilege
          .sort_by(&.encryption_level.as(Encryption::Level))
          # Attain (if exists) setting for given key
          .compact_map(&.any[key]?)
          # Get the highest privilege setting
          .last
      end
    end

    # Decrypt and pick off the setting
    #
    def get_setting_for?(user, setting) : YAML::Any?
      Settings.get_setting_for(user, setting, [self])
    end

    # Check if top-level settings key present for the supplied user
    #
    def has_key_for?(user, key)
      has_key = keys.try(&.includes?(key))
      has_privilege = Settings.has_privilege?(user, encryption_level.as(Encryption::Level))
      has_key && has_privilege
    end

    # If a Settings has a parent, it's a version
    #
    def is_version? : Bool
      !settings_id.nil?
    end

    # Determine if setting_string is encrypted
    #
    def is_encrypted? : Bool
      Encryption.is_encrypted?(settings_string)
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
      if settings_string.empty?
        {} of YAML::Any => YAML::Any
      else
        YAML.parse(settings_string).as_h
      end
    rescue e
      raise Model::Error.new("Failed to parse YAML settings: #{settings_string}", cause: e)
    end
  end
end
