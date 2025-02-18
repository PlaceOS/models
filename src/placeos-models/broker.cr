require "openssl"
require "random"

require "./base/model"

module PlaceOS::Model
  class Broker < ModelBase
    include PlaceOS::Model::Timestamps

    table :broker

    enum AuthType
      Certificate
      NoAuth
      UserPassword
    end

    attribute auth_type : AuthType = AuthType::UserPassword, converter: Enum::ValueConverter(PlaceOS::Model::Broker::AuthType)

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""

    attribute host : String
    attribute port : Int32 = 1883 # Default MQTT port for non-tls connections
    attribute tls : Bool = false

    attribute username : String?
    attribute password : String?
    attribute certificate : String?
    attribute secret : String = -> { Random::Secure.hex(64) }

    # Regex filters for sensitive data.
    # Matches will be replaced with a hmac_256(secret, match).
    attribute filters : Array(String) = -> { [] of String }

    # Validation
    ###############################################################################################

    validates :name, presence: true
    validates :host, presence: true
    validates :secret, presence: true

    ensure_unique :name

    validate ->Broker.validate_filters(Broker)

    # Validate broker's `filter` regexes
    def self.validate_filters(broker : Broker)
      return if broker.filters.empty?
      # Render regex errors
      error_string = broker.filters.compact_map { |filter|
        error = Regex.error?(filter)
        "'#{filter}' errored with '#{error}'" if error
      }.join(" and")

      broker.validation_error(:filters, error_string) unless error_string.empty?
    end

    # Payload Sanitization
    ###############################################################################################

    # Hash sensitive data from a string using the document's `filters`
    def sanitize(payload : String)
      return payload if self.filters.empty?

      # TODO: Cache and reuse unless filters_changed?
      regex = Regex.union(filters)

      payload.gsub(regex) do |match_string, _|
        hmac_sha256(match_string)
      end
    rescue e : ArgumentError
      raise Model::Error::MalformedFilter.new(self.filters)
    end

    protected def hmac_sha256(data : String)
      OpenSSL::HMAC.hexdigest(OpenSSL::Algorithm::SHA256, self.secret, data)
    end
  end
end
