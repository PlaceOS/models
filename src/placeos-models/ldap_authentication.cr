require "uri"
require "json"
require "./base/model"

module PlaceOS::Model
  # see: https://github.com/omniauth/omniauth-ldap
  class LdapAuthentication < ModelBase
    include PgORM::Timestamps

    table :ldap_strat

    attribute name : String, es_subfield: "keyword"
    attribute port : Int32 = 636

    # One of `"plain"`, `"ssl`", `"tls"`
    attribute auth_method : String = "ssl", inclusion: {in: %w(plain ssl tls)}

    attribute uid : String = "sAMAccountName"
    attribute host : String

    # BaseDN such as dc=intridea, dc=com
    attribute base : String

    # `bind_dn` and `password` are the default credentials to perform user lookups
    attribute bind_dn : String?
    # :ditto:
    attribute password : String?

    # LDAP filter like: (&(uid=%{username})(memberOf=cn=myapp-users,ou=groups,dc=example,dc=com))
    # Can be used instead of `uid`
    attribute filter : String?

    # Association
    ###############################################################################################

    belongs_to Authority, foreign_key: "authority_id"

    # Validation
    ###############################################################################################

    validates :authority_id, presence: true
    validates :name, presence: true
    validates :host, presence: true
    validates :base, presence: true
  end
end
