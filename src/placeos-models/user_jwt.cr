require "./base/jwt"

module PlaceOS::Model
  # TODO: Migrate to human-readable attributes
  struct UserJWT < JWTBase
    PUBLIC = Scope.new("public")
    GUEST  = Scope.new("guest")

    getter iss : String

    @[JSON::Field(converter: Time::EpochConverter)]
    getter iat : Time

    @[JSON::Field(converter: Time::EpochConverter)]
    getter exp : Time

    # getter jti : String

    @[JSON::Field(key: "aud")]
    # The authority's domain
    getter domain : String

    @[JSON::Field(key: "sub")]
    # The user's id
    getter id : String

    # OAuth2 Scopes
    getter scope : Array(Scope)

    @[JSON::Field(key: "u")]
    getter user : Metadata

    delegate is_admin?, is_support?, to: user.permissions

    enum Permissions
      User         = 0
      Support      = 1
      Admin        = 2
      AdminSupport = 3

      def is_admin?
        self >= Permissions::Admin
      end

      def is_support?
        self >= Permissions::Support
      end
    end

    @[Deprecated("Use `domain` instead of `aud`, and `id` instead of `sub`.")]
    def initialize(@iss, @iat, @exp, aud, sub, @user, @scope = [PUBLIC])
      new(@iss, @iat, @exp, aud, sub, @user, @scope)
    end

    def initialize(@iss, @iat, @exp, @domain, @id, @user, @scope = [PUBLIC])
    end

    @[Deprecated("Use #domain instead.")]
    def aud
      @domain
    end

    @[Deprecated("Use #id instead.")]
    def sub
      @id
    end

    def public_scope?
      scope.includes?(PUBLIC)
    end

    def guest_scope?
      scope.includes?(GUEST)
    end

    def get_access(scope_name : String) : Scope::Access
      existing = scope.find &.resource.==(scope_name)

      if existing.nil?
        Log.warn { "scope #{scope_name} not present in JWT" }
        Scope::Access::None
      else
        existing.access
      end
    end

    struct Scope
      @[Flags]
      enum Access
        Read
        Write
      end

      getter resource : String

      getter access : Access

      def initialize(@resource, access : Access? = nil)
        access = Access::All if access.nil?
        @access = access
      end

      def initialize(json : JSON::PullParser)
        scope = self.class.from_json(json)
        @resource = scope.resource
        @access = scope.access
      end

      def to_s(io : IO) : Nil
        io << resource

        # Full assumed without an access field
        unless access == Access::All
          io << '.'
          access.to_s(io)
        end
      end

      def self.from_json(json : JSON::PullParser)
        scope = json.read_string
        tokens = scope.split('.')
        raise "Invalid scope structure: #{scope}" if tokens.empty? || tokens.size > 2

        resource = tokens.first
        access = tokens[1]?.try { |str| Access.parse(str) }
        new(resource, access)
      end

      def to_json(builder : JSON::Builder)
        builder.string to_s
      end
    end

    struct Metadata
      include JSON::Serializable
      @[JSON::Field(key: "n")]
      getter name : String
      @[JSON::Field(key: "e")]
      getter email : String
      @[JSON::Field(key: "p", converter: Enum::ValueConverter(PlaceOS::Model::UserJWT::Permissions))]
      getter permissions : Permissions
      @[JSON::Field(key: "r")]
      getter roles : Array(String)

      def initialize(@name, @email, @permissions = Permissions::User, @roles = [] of String)
      end
    end
  end
end
