require "./base/jwt"

module PlaceOS::Model
  # TODO: Migrate to human-readable attributes
  struct UserJWT < JWTBase
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
    getter scope : Array(String)

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
    def initialize(@iss, @iat, @exp, aud, sub, @user, @scope = ["public"])
      new(@iss, @iat, @exp, aud, sub, @user, @scope)
    end

    def initialize(@iss, @iat, @exp, @domain, @id, @user, @scope = ["public"])
    end

    @[Deprecated("Use #domain instead.")]
    def aud
      @domain
    end

    @[Deprecated("Use #id instead.")]
    def sub
      @id
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
