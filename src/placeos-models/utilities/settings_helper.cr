require "rethinkdb-orm"

require "../settings"

module PlaceOS::Model
  module SettingsHelper
    abstract def settings_hierarchy : Array(Settings)

    # Attain the settings associated with the model
    #
    def settings_collection
      RethinkORM::AssociationCollection(self.class, Settings).new(self)
    end

    # Get the settings at a particular encryption level
    #
    def settings_at(encryption_level : Encryption::Level)
      raise IndexError.new unless (settings = settings_at?(encryption_level))
      settings
    end

    # Get the settings at a particular encryption level
    #
    def settings_at?(encryption_level : Encryption::Level)
      Settings.master_settings_query(self.id.as(String)) do |q|
        q.filter({encryption_level: encryption_level.to_i})
      end.first?
    end

    # Decrypts and merges all settings for the model
    #
    # Lower privilged settings are favoured during the merge process.
    def all_settings : Hash(YAML::Any, YAML::Any)
      master_settings
        .reverse!
        .each_with_object({} of YAML::Any => YAML::Any) do |settings, acc|
          # Parse and merge into accumulated settings hash
          begin
            acc.merge!(settings.any)
          rescue error
            Log.warn(exception: error) { "failed to merge all settings: #{settings.inspect}" }
          end
        end
    end

    # Decrypted JSON object for configuring drivers
    #
    def settings_json : String
      all_settings.to_json
    end

    # Query the master settings attached to a model
    #
    def master_settings : Array(Settings)
      Settings.master_settings_query(self.id.as(String), &.itself)
    end
  end
end
