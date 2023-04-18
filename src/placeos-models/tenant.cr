require "json"
require "./base/model"
require "./utilities/encryption"
require "./tenant/outlook_config"
require "./guest"
require "./event_metadata"

module PlaceOS::Model
  class Tenant < ModelWithAutoKey
    table :tenants

    attribute name : String?
    attribute domain : String
    attribute platform : String
    attribute credentials : String
    attribute booking_limits : JSON::Any = JSON::Any.new({} of String => JSON::Any)
    attribute outlook_config : OutlookConfig?

    attribute delegated : Bool = false
    attribute service_account : String?

    has_many(
      child_class: Attendee,
      collection_name: "attendees",
      foreign_key: "tenant_id",
      dependent: :destroy
    )

    has_many(
      child_class: Guest,
      collection_name: "guests",
      foreign_key: "tenant_id",
      dependent: :destroy
    )

    has_many(
      child_class: EventMetadata,
      collection_name: "event_metadata",
      foreign_key: "tenant_id",
      dependent: :destroy
    )

    validates :domain, :platform, :credentials, presence: true
    ensure_unique :domain

    before_save :set_delegated
    before_save :encrypt!

    validate ->(this : Tenant) {
      # this.validation_error(:domain, "must be defined") unless this.domain.presence
      # this.validation_error(:platform, "must be defined") unless this.platform.presence
      this.validation_error(:platform, "must be a valid platform name") unless VALID_PLATFORMS.includes?(this.platform)
      # this.validation_error(:credentials, "must be defined") unless this.credentials.presence

      # Try parsing the JSON for the relevant platform to make sure it works
      begin
        creds = this.decrypt_credentials
        this.validation_error(:credentials, "must be valid JSON") unless (JSON.parse(creds) rescue nil)

        if this.delegated
          case this.platform
          when "google"
            GoogleDelegatedConfig.from_json(creds)
          when "office365"
            Office365DelegatedConfig.from_json(creds)
          end
        else
          case this.platform
          when "google"
            GoogleConfig.from_json(creds)
          when "office365"
            Office365Config.from_json(creds)
          end
        end
      rescue e : JSON::SerializableError
        this.validation_error(:credentials, e.message.to_s)
      end

      # Try parsing the JSON for booking limits in lieu of a stronger column type
      begin
        if booking_limits = this.booking_limits
          Hash(String, Int32).from_json(booking_limits.to_json)
        end
      rescue e : JSON::ParseException
        this.validation_error(:booking_limits, e.message.to_s)
      end
    }

    struct Responder
      include JSON::Serializable

      getter id : Int64?
      getter name : String?
      getter domain : String?
      getter platform : String?
      getter delegated : Bool?
      getter service_account : String?
      getter credentials : JSON::Any? = nil
      getter booking_limits : JSON::Any? = nil
      getter outlook_config : OutlookConfig? = nil

      def initialize(@id, @name, @domain, @platform, @delegated, @service_account, @credentials = nil, @booking_limits = nil, @outlook_config = nil)
      end

      def to_tenant(update : Bool = false)
        tenant = Tenant.new
        {% for key in [:name, :domain, :platform, :delegated, :service_account, :outlook_config] %}
          tenant.{{key.id}} = self.{{key.id}}.not_nil! unless self.{{key.id}}.nil?
        {% end %}

        if creds = credentials
          tenant.credentials = creds.to_json unless update && creds.as_h.empty?
        elsif !update
          tenant.credentials = "{}"
        end

        if limits = booking_limits
          tenant.booking_limits = limits unless update && limits.as_h.empty?
        end

        tenant
      end
    end

    def as_json
      is_delegated = self.delegated || false
      limits = self.booking_limits || JSON::Any.new({} of String => JSON::Any)
      service = self.service_account
      outlook_config = self.outlook_config

      Responder.new(
        id: self.id,
        name: self.name,
        domain: self.domain,
        platform: self.platform,
        service_account: service,
        delegated: is_delegated,
        booking_limits: limits,
        outlook_config: outlook_config,
      )
    end

    def valid_json?(value : String)
      true if JSON.parse(value)
    rescue JSON::ParseException
      false
    end

    def place_calendar_client
      raise "not supported, using delegated credentials" if delegated

      case platform
      when "office365"
        params = Office365Config.from_json(decrypt_credentials).params
        ::PlaceCalendar::Client.new(**params)
      when "google"
        params = GoogleConfig.from_json(decrypt_credentials).params
        ::PlaceCalendar::Client.new(**params)
      end
    end

    def place_calendar_client(bearer_token : String, expires : Int64?)
      case platform
      when "office365"
        params = Office365DelegatedConfig.from_json(decrypt_credentials).params
        cal = ::PlaceCalendar::Office365.new(bearer_token, **params, delegated_access: true)
        ::PlaceCalendar::Client.new(cal)
      when "google"
        params = GoogleDelegatedConfig.from_json(decrypt_credentials).params
        auth = ::Google::TokenAuth.new(bearer_token, expires || 5.hours.from_now.to_unix)
        cal = ::PlaceCalendar::Google.new(auth, **params, delegated_access: true)
        ::PlaceCalendar::Client.new(cal)
      end
    end

    # Encryption
    ###########################################################################

    protected def encrypt(string : String)
      raise PlaceOS::Model::Error::NoParent.new if (encryption_id = self.domain).nil?

      PlaceOS::Encryption.encrypt(string, id: encryption_id, level: PlaceOS::Encryption::Level::NeverDisplay)
    end

    # Encrypts credentials
    #
    protected def encrypt_credentials
      self.credentials = encrypt(self.credentials)
    end

    # Encrypt in place
    #
    def encrypt!
      encrypt_credentials
      self
    end

    # ensure delegated column has been defined
    def set_delegated
      self.delegated = false if self.delegated.nil?
      self
    end

    # Decrypts the tenants's credentials string
    #
    protected def decrypt_credentials
      raise PlaceOS::Model::Error::NoParent.new if (encryption_id = self.domain).nil?

      PlaceOS::Encryption.decrypt(string: self.credentials, id: encryption_id, level: PlaceOS::Encryption::Level::NeverDisplay)
    end

    def decrypt_for!(user)
      self.credentials = decrypt_for(user)
      self
    end

    # Decrypts (if user has correct privilege) and returns the credentials string
    #
    def decrypt_for(user) : String
      raise PlaceOS::Model::Error::NoParent.new unless encryption_id = self.domain

      PlaceOS::Encryption.decrypt_for(user: user, string: self.credentials, level: PlaceOS::Encryption::Level::NeverDisplay, id: encryption_id)
    end

    # Determine if attributes are encrypted
    #
    def is_encrypted? : Bool
      PlaceOS::Encryption.is_encrypted?(self.credentials)
    end

    # distribute load as much as possible when using service accounts
    def which_account(user_email : String, resources = [] of String) : String
      if service_acct = self.service_account.presence
        resources << service_acct
        resources.sample.downcase
      else
        user_email.downcase
      end
    end

    def using_service_account?
      !self.service_account.presence.nil?
    end
  end
end
