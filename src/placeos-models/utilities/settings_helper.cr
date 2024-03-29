require "../settings"

module PlaceOS::Model::Utilities
  module SettingsHelper
    abstract def settings_hierarchy : Array(Settings)

    # Query the master settings attached to a model
    #
    def settings : Array(Settings)
      Settings.for_parent(self.id.as(String))
    end

    # Get the settings at a particular encryption level
    #
    def settings_at(encryption_level : Encryption::Level)
      raise IndexError.new unless (settings_at_level = settings_at?(encryption_level))
      settings_at_level
    end

    # Get the settings at a particular encryption level
    #
    def settings_at?(encryption_level : Encryption::Level)
      Settings.for_parent(self.id.as(String)) do |q|
        q.filter({encryption_level: encryption_level.to_i})
      end.first?
    end

    # Decrypts and merges all settings for the model
    #
    # Lower privilged settings are favoured during the merge process.
    def all_settings : Hash(YAML::Any, YAML::Any)
      settings
        .each_with_object({} of YAML::Any => YAML::Any) do |setting, acc|
          # Parse and merge into accumulated settings hash
          begin
            acc.merge!(setting.any)
          rescue error
            Log.warn(exception: error) { "failed to merge all settings: #{setting.inspect}" }
          end
        end
    end

    # Decrypted JSON object for configuring drivers
    #
    def settings_json : String
      all_settings.to_json
    end
  end
end
