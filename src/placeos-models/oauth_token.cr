require "./base/model"

module PlaceOS::Model
  # Persistence backing for the auth.cr `AuthlyAdapter::TokenStore`.
  # Each row records the metadata of a single OAuth2 access or refresh
  # token; the `revoked_at` column lets the auth service mark a token
  # invalid without rotating signing keys.
  #
  # See migration `20260519100000000_add_oauth_tokens.sql` for the
  # column rationale (notably: most columns are nullable so a revoke
  # for a never-stored refresh token can still leave a marker).
  class OAuthToken < ModelWithAutoKey
    table :oauth_tokens

    attribute jti : String
    attribute token_type : String? = nil
    attribute client_id : String? = nil
    attribute sub : String? = nil
    attribute scope : String? = nil
    attribute issued_at : Int64? = nil
    attribute expires_at : Int64? = nil
    attribute cert_thumbprint : String? = nil
    attribute revoked_at : Int64? = nil

    ensure_unique :jti

    validates :jti, presence: true

    # `true` if the token has been marked revoked via `revoked_at`.
    def revoked? : Bool
      !@revoked_at.nil?
    end

    # Stamps `revoked_at` to the current time (epoch seconds) and
    # saves. No-op if already revoked.
    def revoke! : Nil
      return if revoked?
      self.revoked_at = Time.utc.to_unix
      save!
    end
  end
end
