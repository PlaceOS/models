require "uri"
require "json"

require "./base/model"

module PlaceOS::Model
  # See: https://github.com/omniauth/omniauth-oauth2
  class OAuthAuthentication < ModelBase
    include PlaceOS::Model::Timestamps

    table :oauth_strat

    attribute name : String, es_subfield: "keyword"

    # The client ID configured for this application
    attribute client_id : String

    # The secret configured for this application
    attribute client_secret : String

    # Maps an expected key to a provided key i.e. {used_in_engine => used_by_remote}
    attribute info_mappings : Hash(String, String) = {} of String => String

    # Maps additional params to be added to the authorisation request
    attribute authorize_params : Hash(String, String) = {} of String => String

    # Security checks to be made on the returned data
    attribute ensure_matching : Hash(String, Array(String)) = {} of String => Array(String)

    # The HTTP URL of the SSO provider
    attribute site : String

    # The SSO providers URL for authorization, defaults to: `oauth/authorize`
    # Google is `/o/oauth2/auth`
    attribute authorize_url : String = "/oauth/authorize"

    # If not set it defaults to "post"
    attribute token_method : String = "post"

    # If not set it defaults to "request_body", others include "basic_auth"
    attribute auth_scheme : String = "request_body"

    # defaults to: `oauth/token` however google is: `/o/oauth2/token`
    attribute token_url : String = "/oauth/token"

    # Space separated scope strings
    # i.e. `https://www.googleapis.com/auth/devstorage.readonly https://www.googleapis.com/auth/prediction`
    attribute scope : String

    # URL to call with a valid token to obtain the users profile data (name, email etc)
    attribute raw_info_url : String?

    # Association
    ###############################################################################################

    belongs_to Authority, foreign_key: "authority_id"

    # Validation
    ###############################################################################################

    validates :name, presence: true
    validates :authority_id, presence: true
  end
end
