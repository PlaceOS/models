require "uri"
require "json"
require "./base/model"

module PlaceOS::Model
  # See: https://github.com/omniauth/omniauth-saml
  class SamlAuthentication < ModelBase
    include PgORM::Timestamps

    table :adfs_strat

    attribute name : String, es_subfield: "keyword"

    # The name of your application
    attribute issuer : String = "place.technology"

    # mapping of request params that exist during the request phase of OmniAuth that should to be sent to the IdP
    attribute idp_sso_target_url_runtime_params : Hash(String, String) = {} of String => String

    # Describes the format of the username required by this application
    attribute name_identifier_format : String = "urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified"

    # Attribute that uniquely identifies the user
    # (If unset, the name identifier returned by the IdP is used.)
    attribute uid_attribute : String?

    # The URL at which the SAML assertion should be received (SSO Service => Engine URL)
    attribute assertion_consumer_service_url : String

    # The URL to which the authentication request should be sent (Engine => SSO Service)
    attribute idp_sso_target_url : String

    # The identity provider's certificate in PEM format (this or fingerprint is required)
    attribute idp_cert : String?

    # The SHA1 fingerprint of the certificate
    attribute idp_cert_fingerprint : String?

    # Name for the attribute service (Defaults to Required attributes)
    attribute attribute_service_name : String?

    # Used to map Attribute Names in a SAMLResponse to entries in the OmniAuth info hash
    attribute attribute_statements : Hash(String, Array(String)) = {
      "name"       => ["name"],
      "email"      => ["email", "mail"],
      "last_name"  => ["last_name", "lastname", "lastName", "surname"],
      "first_name" => ["first_name", "firstname", "firstName", "givenname"],
    }

    # Used to map Attribute Names in a SAMLResponse to entries in the OmniAuth info hash
    attribute request_attributes : Array(NamedTuple(name: String, name_format: String, friendly_name: String)) = [
      {name: "ImmutableID", name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic", friendly_name: "Login Name"},
      {name: "email", name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic", friendly_name: "Email address"},
      {name: "name", name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic", friendly_name: "Full name"},
      {name: "first_name", name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic", friendly_name: "Given name"},
      {name: "last_name", name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic", friendly_name: "Family name"},
    ], converter: PlaceOS::Model::DBArrConverter(NamedTuple(name: String, name_format: String, friendly_name: String))

    # The URL to which the single logout request and response should be sent
    attribute idp_slo_target_url : String?

    # The value to use as default RelayState for single log outs
    attribute slo_default_relay_state : String?

    # Association
    ###############################################################################################

    belongs_to Authority, foreign_key: "authority_id"

    # Validation
    ###############################################################################################

    validates :authority_id, presence: true
    validates :name, presence: true
    validates :issuer, presence: true
    validates :idp_sso_target_url, presence: true
    validates :name_identifier_format, presence: true
    validates :assertion_consumer_service_url, presence: true
  end
end
