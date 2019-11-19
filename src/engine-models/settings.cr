require "rethinkdb-orm"
require "time"

require "./base/model"
require "./error"
require "./utilities/encryption"

# Could you parameterise on the parent model?
# It sould be generic on the model...
# So then you would have Settings(T), not sure that would work
module ACAEngine::Model
  # TODO: Statically ensure a single parent id exists on the table
  class Settings < ModelBase
    include RethinkORM::Timestamps

    table :sets

    attribute parent_id : String
    attribute encryption : Encryption::Level
    attribute settings_string : String = "{}"
    attribute keys : Array(String) = [] of String

    # Settings self-referential entity relationship acts as a 2-level tree
    has_many Settings, collection_name: "settings", dependent: :destroy

    belongs_to Zone, dependent: :destroy
    belongs_to ControlSystem, dependent: :destroy
    belongs_to Driver, dependent: :destroy
    belongs_to Module, dependent: :destroy, association_name: :mod

    validates :parent_id, prescence: true
    validate ->self.single_parent?(Settings)

    before_save :build_keys
    before_save :encrypt_settings

    def build_keys : Array(String)
      raise NoParentError.new unless (encryption_id = @parent_id)

      settings_string = @settings_string.as(String)
      encryption = @encryption.as(Encryption::Level)
      decrypted = Encryption.decrypt(string: settings_string, level: encryption, id: encryption_id)

      self.keys = YAML.parse(decrypted).as_h.keys.map(&.to_s)
    end

    # Encrypts all settings.
    #
    def encrypt_settings
      raise NoParentError.new unless (encryption_id = @parent_id)

      settings_string = @settings_string.as(String)
      encryption = @encryption.as(Encryption::Level)

      self.settings_string = Encryption.encrypt(string: settings_string, level: encryption, id: encryption_id)
    end

    # Queries
    ###########################################################################

    # Get version history
    #
    # TODO: ranges
    def history
      Settings.get_all([id], index: :settings_id).as_a.sort_by!(&.created_at)
    end

    # Validators
    ###########################################################################

    protected def self.single_parent?(this : Settings) : Bool
      parent_ids = {this.zone_id, this.control_system_id, this.driver_id, this.mod_id}
      if parent_ids.one?
        true
      else
        this.validation_error(:parent_id, "there can only be a single parent id #{parent_ids.inspect}")
        false
      end
    end

    # Parent accessors set the model id, used for encryption
    ###########################################################################

    def zone=(zone : Zone)
      self.parent_id = zone.id
      previous_def(zone)
    end

    def control_system=(cs : ControlSystem)
      self.parent_id = cs.id
      previous_def(cs)
    end

    def driver=(driver : Driver)
      self.parent_id = driver.id
      previous_def(driver)
    end

    def mod=(mod : Module)
      self.parent_id = mod.id
      previous_def(mod)
    end

    # Helpers
    ###########################################################################

    # If a Settings has a parent, it's a version
    #
    def is_version? : Bool
      !!(@settings_id)
    end

    # Decrypts settings dependent on user privileges
    #
    def decrypt_for!(user)
      self.settings_string = decrypt_for(user)
      self
    end

    def decrypt_for(user) : String
      raise NoParentError.new unless (encryption_id = @parent_id)

      settings_string = @settings_string.as(String)
      encryption = @encryption.as(Encryption::Level)

      case encryption
      when Encryption::Level::Support && (user.is_support? || user.is_admin?)
        Encryption.decrypt(string: settings_string, level: level, id: encryption_id)
      when Encryption::Level::Admin && user.is_admin?
        Encryption.decrypt(string: settings_string, level: level, id: encryption_id)
      else
        settings_string
      end
    end

    # Decrypt and pick off the setting
    #
    def get_setting_for(user, setting) : YAML::Any?
      return unless @id

      decrypted_settings = decrypt_for(user)
      YAML.parse(decrypted)[setting]? unless Encryption.is_encrypted?(decrypted_settings)
    end

    # Decrypts settings, merges into single JSON object
    #
    def settings_json
      raise NoParentError.new unless (encryption_id = @parent_id)
      YAML.parse(ACAEngine::Encryption.decrypt(string: settings_string, level: level, id: encryption_id)).to_json
    end
  end
end
