require "random"
require "crypto/bcrypt"

require "./base/model"
require "./user_jwt"

module PlaceOS::Model
  class ApiKey < ModelBase
    include PlaceOS::Model::Timestamps

    table :api_key

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""

    attribute scopes : Array(UserJWT::Scope) = [UserJWT::Scope::PUBLIC], converter: PlaceOS::Model::DBArrConverter(PlaceOS::Model::UserJWT::Scope), es_type: "keyword"

    attribute permissions : UserJWT::Permissions? = UserJWT::Permissions::User, es_type: "integer"

    attribute secret : String = ->{ Random::Secure.urlsafe_base64(32) }, mass_assignment: false

    belongs_to User
    belongs_to Authority

    macro finished
      def user=(user)
        self.authority_id = user.authority_id
        super(user)
      end
    end

    def permissions : UserJWT::Permissions
      @permissions || UserJWT::Permissions::User
    end

    # Serialisation
    ###############################################################################################

    define_to_json :public, only: [
      :name, :description, :scopes, :user_id, :authority_id, :created_at,
      :updated_at,
    ], methods: [:user, :authority, :x_api_key, :permissions, :id]

    # Validation
    ###############################################################################################

    # Ensure name is unique under the authority scope
    #
    ensure_unique :name, scope: [:authority_id, :name] do |authority_id, name|
      {authority_id, name.strip.downcase}
    end

    # Callbacks
    ###############################################################################################

    before_create :safe_id
    before_create :set_authority
    before_create :x_api_key
    before_create :hash!

    protected def safe_id
      self.new_record = true
      @id ||= Random.new.hex(16)
    end

    protected def set_authority
      self.authority_id = self.user.not_nil!.authority_id.not_nil!
    end

    # obscure the API key
    protected def hash!
      self.secret = OpenSSL::HMAC.hexdigest(:sha512, self.secret.not_nil!, self.id.not_nil!)
      self
    end

    # Token Methods
    ###############################################################################################

    @[JSON::Field(ignore: true)]
    getter x_api_key : String? do
      return nil if self.persisted?
      "#{self.safe_id}.#{self.secret}"
    end

    def self.find_key!(token : String)
      id, secret = token.split('.', 2)

      model = Model::ApiKey.find!(id)

      # Same error as being unable to find the model
      if model.secret != OpenSSL::HMAC.hexdigest(:sha512, secret, id)
        raise PgORM::Error::RecordNotFound.new("Key not present: #{id}")
      end

      model
    end

    def build_jwt
      ident = self.user.not_nil!

      UserJWT.new(
        iss: UserJWT::ISSUER,
        iat: 5.minutes.ago,
        exp: 1.hour.from_now,
        domain: self.authority.not_nil!.domain,
        scope: self.scopes,
        id: ident.id.not_nil!,
        user: UserJWT::Metadata.new(
          name: ident.name.not_nil!,
          email: ident.email.to_s,
          permissions: self.permissions || ident.to_jwt_permission,
          roles: ident.groups.not_nil!
        ),
      )
    end

    # Builds an API token for a SaaS instance.
    # Used to delegate control of the instance by the PortalAPI.
    def self.saas_api_key(instance_domain, instance_email) : String?
      unless authority = Model::Authority.find_by_domain(instance_domain)
        raise Model::Error::InvalidSaasKey.new("authority does not exist for #{instance_domain}")
      end

      authority_id = authority.id.as(String)

      # Fetch token for instance user
      unless user = Model::User.find_by_email(authority_id, instance_email)
        raise Model::Error::InvalidSaasKey.new("instance user does not exist for #{instance_email}")
      end

      user_id = user.id.as(String)
      saas_scope = UserJWT::Scope::SAAS.to_s
      public_scope = UserJWT::Scope::PUBLIC.to_s
      existing_key = Model::ApiKey.where(authority_id: authority_id, user_id: user_id, scopes: [saas_scope, public_scope].to_json).first?
      if existing_key.nil?
        key = Model::ApiKey.new(
          name: "Portal SaaS Key",
          description: "Key for PortalAPI to manage SaaS instances",
          scopes: [UserJWT::Scope::SAAS, UserJWT::Scope::PUBLIC],
        )

        key.user = user
        key.authority = authority
        token = key.x_api_key.as(String)
        key.save!
        Log.info { {
          message:         "created SaaS API key",
          instance_domain: instance_domain,
          instance_email:  instance_email,
        } }
        token
      else
        Log.info { {
          message:         "existing SaaS API key",
          instance_domain: instance_domain,
          instance_email:  instance_email,
        } }
        nil
      end
    end
  end
end
