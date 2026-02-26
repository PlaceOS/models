require "./base/model"
require "./converter/json_string"
require "./utilities/settings_helper"

require "./repository"
require "./settings"

module PlaceOS::Model
  class Driver < ModelBase
    include PlaceOS::Model::Timestamps
    include Utilities::SettingsHelper

    table :driver

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""
    attribute json_schema : JSON::Any = JSON::Any.new({} of String => JSON::Any), converter: JSON::Any::StringConverter, es_type: "text"

    attribute default_uri : String?
    attribute default_port : Int32?

    enum Role
      SSH       =  0
      Device    =  1
      Service   =  2
      Websocket =  3
      Logic     = 99

      def to_json(json)
        json.number value
      end
    end

    attribute role : Role, es_type: "integer", converter: Enum::ValueConverter(PlaceOS::Model::Driver::Role)

    attribute alert_level : Alert::Severity = Alert::Severity::MEDIUM, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::Alert::Severity),
      description: "the default alert level for stagehand issues"

    # Path to driver, relative to repository directory
    attribute file_name : String

    # Commit/version of driver to compile
    attribute commit : String

    # Output of the last failed compilation
    attribute compilation_output : String?

    # Module instance configuration
    attribute module_name : String

    # Don't include this module in statistics or disconnected searches
    # Might be a device that commonly goes offline (like a PC or Display that only supports Wake on Lan)
    attribute ignore_connected : Bool = false

    record UpdateInfo, commit : String, message : String, author : String? = nil, date : String? = nil do
      include JSON::Serializable
    end

    attribute update_available : Bool = false
    attribute update_info : UpdateInfo? = nil, converter: OptionalRecordConverter(PlaceOS::Model::Driver::UpdateInfo)

    # Association
    ###############################################################################################
    belongs_to Repository, foreign_key: "repository_id", presence: true

    # Encrypted yaml settings
    has_many(
      child_class: Settings,
      collection_name: "settings_and_versions",
      foreign_key: "parent_id",
      dependent: :destroy
    )

    # Queries
    ###############################################################################################

    # Find the modules that rely on this driver
    def modules
      Module.by_driver_id(self.id)
    end

    def settings_hierarchy : Array(Settings)
      settings
    end

    # Callbacks
    ###############################################################################################

    before_save :check_update_available

    after_save :update_modules

    before_destroy :cleanup_modules

    # Reload all modules to update their name
    #
    protected def update_modules
      # TODO: Perform asynchronously
      self.modules.each do |mod|
        mod.driver = self
        mod.save
      end
    end

    # Delete all the module references relying on this driver
    #
    protected def cleanup_modules
      # TODO: Perform asynchronously
      self.modules.each &.destroy
    end

    # sets update_available appropriately
    protected def check_update_available
      if update_available
        self.update_available = false if self.commit == self.update_info.try(&.commit)
      end
    end

    # Validation
    ###############################################################################################

    validates :name, presence: true
    validates :module_name, presence: true
    validates :file_name, presence: true
    validates :commit, presence: true

    # Validate the repository type
    #
    validate ->(this : Driver) {
      return if (repo = this.repository).nil?
      this.validation_error(:repository, "should be a driver repository") unless repo.repo_type.driver?
    }

    # Overridden attribute accessors
    ###############################################################################################

    def default_port=(port)
      self.role = Role::Device
      self.default_port = port
    end

    def default_uri=(uri)
      self.role = Role::Service
      self.default_uri = uri
    end

    # Recompilation Helpers
    ###############################################################################################

    RECOMPILE_PREFIX = "RECOMPILE-"

    # Returns the commit hash if the driver has a recompile commit hash
    def recompile_commit?
      commit_hash = self.commit
      if commit_hash && commit_hash.starts_with?(RECOMPILE_PREFIX)
        commit_hash.lchop(RECOMPILE_PREFIX)
      end
    end

    # Sets the commit hash of the driver for a recompile event
    def recompile(commit_hash : String? = nil)
      commit_hash ||= self.commit
      self.update_fields(commit: RECOMPILE_PREFIX + commit_hash) if commit_hash
    end

    def process_update_info(info : UpdateInfo)
      return if info.commit[0...self.commit.size] == self.commit
      self.update_available = true
      self.update_info = info
      self.save!
    end

    # Returns the list of Drivers which has update available
    def self.require_updates : Array(self)
      Driver.where(update_available: true).to_a
    end
  end
end
