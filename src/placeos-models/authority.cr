require "uri"
require "json"

require "./base/model"
require "./ldap_authentication"
require "./oauth_authentication"
require "./saml_authentication"
require "./user"

module PlaceOS::Model
  class Authority < ModelBase
    include PlaceOS::Model::Timestamps

    table :authority

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""
    attribute domain : String

    # TODO: feature request: autogenerate login url
    attribute login_url : String = "/login?continue={{url}}"
    attribute logout_url : String = "/auth/logout"

    attribute internals : Hash(String, JSON::Any) = {} of String => JSON::Any
    attribute config : Hash(String, JSON::Any) = {
      "default_app" => JSON::Any.new("/backoffice/"),
    }

    attribute email_domains : Array(String) = [] of String

    macro finished
      # Ensure only the host is saved.
      #
      def domain=(value : String)
        uri = URI.parse(value)
        host = (uri.host || uri.path || "").downcase
        previous_def(host)
      end
    end

    # Associations
    ###############################################################################################

    {% for relation, _idx in [
                               {LdapAuthentication, "ldap_authentications"},
                               {OAuthAuthentication, "oauth_authentications"},
                               {SamlAuthentication, "saml_authentications"},
                               {User, "users"},
                             ] %}
      has_many(
        child_class: {{relation[0].id}},
        collection_name: {{relation[1].stringify.id}},
        foreign_key: "authority_id",
        dependent: :destroy
      )
    {% end %}

    # Validation
    ###############################################################################################

    validates :domain, presence: true
    validates :name, presence: true

    ensure_unique :domain

    # Queries
    ###########################################################################

    # Locates an authority by its unique domain name
    #
    def self.find_by_domain(domain : String) : Authority?
      host = URI.parse(domain).host || domain
      Authority.where(domain: host).first?
    end

    # Locates an authority by email domain
    def self.find_by_email(email : String) : Authority?
      parts = email.split('@', 2)
      return nil unless parts.size == 2
      search_domain = parts[1].downcase
      Authority.where("email_domains @> ARRAY['#{search_domain}']").first?
    end
  end
end
