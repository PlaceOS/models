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

    def user=(user : User)
      self.authority_id = user.authority_id
      super(user)
    end

    secondary_index :authority_id

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
    before_create :hash!

    # Reject '+' and '~'
    protected def safe_id
      self._new_flag = true
      @id ||= RethinkORM::IdGenerator.next(self).gsub({"+": '-', "~": '-'}).split('-', 2)[1]
      @id
    end

    protected def set_authority
      self.authority_id = self.user.not_nil!.authority_id.not_nil!
    end

    # obscure the API key
    protected def hash!
      self.secret = Crypto::Bcrypt.new(self.secret, self.id.not_nil!).digest.hexstring
      self
    end

    # Token Methods
    ###############################################################################################

    def x_api_key
      raise "API key has already been hashed" if self.persisted?
      "#{self.safe_id}.#{self.secret}"
    end

    def self.find_key!(token : String)
      id, secret = token.split('.', 2)

      model = Model::ApiKey.find!(id)

      # Same error as being unable to find the model
      if model.secret != Crypto::Bcrypt.new(secret, id).digest.hexstring
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
