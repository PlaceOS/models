require "./base/model"

module PlaceOS::Model
  class SignagePlugin < ModelBase
    include PlaceOS::Model::Timestamps

    table :signage_plugin

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""

    belongs_to Authority, foreign_key: "authority_id"

    attribute enabled : Bool = true
    attribute params : Hash(String, JSON::Any) = {} of String => JSON::Any
    attribute defaults : Hash(String, JSON::Any) = {} of String => JSON::Any

    # Validation
    ###############################################################################################

    validates :name, presence: true

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
