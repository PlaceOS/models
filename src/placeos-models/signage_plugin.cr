require "uri"
require "./base/model"

module PlaceOS::Model
  class SignagePlugin < ModelBase
    include PlaceOS::Model::Timestamps

    table :signage_plugin

    enum PlaybackType
      STATIC
      INTERACTIVE
      PLAYSTHROUGH
    end

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""
    attribute uri : String
    attribute playback_type : PlaybackType = PlaybackType::STATIC, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::SignagePlugin::PlaybackType)

    belongs_to Authority, foreign_key: "authority_id"

    attribute enabled : Bool = true
    attribute params : Hash(String, JSON::Any) = {} of String => JSON::Any
    attribute defaults : Hash(String, JSON::Any) = {} of String => JSON::Any

    # Validation
    ###############################################################################################

    validates :name, presence: true
    validates :uri, presence: true

    validate ->(this : SignagePlugin) {
      return unless uri = this.uri.presence
      begin
        parsed = URI.parse(uri)
        raise "requires a request target" unless parsed.request_target.presence
        if scheme = parsed.scheme
          raise "scheme must be https" unless scheme.downcase == "https"
        end
      rescue error
        this.validation_error(:uri, "not valid: #{error.message}")
      end
    }

    # ensure keys in defaults exist in params properties
    validate ->(this : SignagePlugin) {
      return if this.defaults.empty?

      properties = this.params["properties"]?.try(&.as_h?)

      this.defaults.each_key do |key|
        unless properties.try(&.has_key?(key))
          this.validation_error(:defaults, "key '#{key}' does not exist in params properties")
        end
      end
    }
  end
end
