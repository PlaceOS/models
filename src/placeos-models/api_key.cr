require "random"
require "crypto/bcrypt"

require "./base/model"
require "./user_jwt"

module PlaceOS::Model
  class ApiKey < ModelBase
    include RethinkORM::Timestamps

    table :api_key

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""
    attribute scopes : Array(String) = ["public"]

    # when nil it defaults to the users permissions
    attribute permissions : UserJWT::Permissions? = nil

    attribute secret : String = ->{ Random::Secure.urlsafe_base64(32) }, mass_assignment: false

    belongs_to User
    belongs_to Authority

    secondary_index :authority_id

    macro finished
      def user=(user)
        super(user)
        self.authority_id = user.authority_id
      end

      def permissions
        @permissions || self.user.try &.to_jwt_permission
      end
    end

    # Serialisation
    ###############################################################################################

    define_to_json :public, only: [
      :name, :description, :scopes, :user_id, :authority_id, :created_at,
      :updated_at, :id,
    ], methods: [:user, :authority, :x_api_key, :permissions]

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
      self._new_flag = true
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

    def x_api_key
      xkey = @x_api_key
      return xkey if xkey
      return nil if self.persisted?
      @x_api_key = "#{self.safe_id}.#{self.secret}"
    end

    def self.find_key!(token : String)
      id, secret = token.split('.', 2)

      model = Model::ApiKey.find!(id)

      # Same error as being unable to find the model
      if model.secret != OpenSSL::HMAC.hexdigest(:sha512, secret, id)
        raise RethinkORM::Error::DocumentNotFound.new("Key not present: #{id}")
      end

      model
    end

    ISSUER = "POS"

    def build_jwt
      ident = self.user.not_nil!

      UserJWT.new(
        iss: ISSUER,
        iat: 5.minutes.ago,
        exp: 1.hour.from_now,
        domain: self.authority.not_nil!.domain,
        scope: self.scopes,
        id: ident.id.not_nil!,
        user: UserJWT::Metadata.new(
          name: ident.name.not_nil!,
          email: ident.email.not_nil!,
          permissions: self.permissions || ident.to_jwt_permission,
          roles: ident.groups.not_nil!
        ),
      )
    end
  end
end
