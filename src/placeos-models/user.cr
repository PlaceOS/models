require "CrystalEmail"
require "crypto/bcrypt/password"
require "digest/md5"
require "./base/model"
require "./api_key"
require "./metadata"
require "./email"
require "./utilities/metadata_helper"

module PlaceOS::Model
  class User < ModelBase
    include PlaceOS::Model::Timestamps
    include Utilities::MetadataHelper

    table :user

    # start_time: Start time of work hours. e.g. `7.5` being 7:30AM
    # end_time: End time of work hours. e.g. `18.5` being 6:30PM
    # location: Name of the location the work is being performed at
    struct WorktimeBlock
      include JSON::Serializable

      property start_time : Float64
      property end_time : Float64
      property location : String = ""
    end

    # day_of_week: Index of the day of the week. `0` being Sunday
    struct WorktimePreference
      include JSON::Serializable

      property day_of_week : Int32
      property blocks : Array(WorktimeBlock) = [] of WorktimeBlock
    end

    attribute name : String, es_subfield: "keyword"
    attribute nickname : String?
    attribute email : Email = Email.new(""), converter: PlaceOS::Model::EmailConverter, es_type: "text"
    attribute phone : String?
    attribute country : String?
    attribute image : String?
    attribute ui_theme : String? = "light"
    attribute misc : String?

    attribute login_name : String?, mass_assignment: false
    attribute staff_id : String?, mass_assignment: false
    attribute first_name : String?
    attribute last_name : String?
    attribute building : String?
    attribute department : String?
    attribute preferred_language : String?

    attribute password_digest : String?, mass_assignment: false
    attribute email_digest : String?, mass_assignment: false
    attribute card_number : String?, mass_assignment: false

    attribute deleted : Bool = false, mass_assignment: false
    attribute groups : Array(String) = [] of String, mass_assignment: false

    attribute access_token : String?, mass_assignment: false
    attribute refresh_token : String?, mass_assignment: false
    attribute expires_at : Int64?, mass_assignment: false
    attribute expires : Bool = false, mass_assignment: false

    attribute password : String?

    attribute sys_admin : Bool = false, mass_assignment: false
    attribute support : Bool = false, mass_assignment: false
    attribute locatable : Bool = true

    attribute login_count : Int64 = 0
    attribute last_login : Time? = nil, converter: Time::EpochConverterOptional, type: "integer", format: "Int64"
    attribute logged_out_at : Time? = nil

    attribute work_preferences : Array(WorktimePreference) = [] of WorktimePreference, converter: PlaceOS::Model::DBArrConverter(PlaceOS::Model::User::WorktimePreference)
    attribute work_overrides : Hash(String, WorktimePreference) = {} of String => WorktimePreference, converter: PlaceOS::Model::DBHashConverter(String, PlaceOS::Model::User::WorktimePreference)

    # Association
    ################################################################################################

    belongs_to Authority
    belongs_to Upload, foreign_key: :photo_upload_id

    has_many(
      child_class: UserAuthLookup,
      collection_name: "auth_lookups",
      foreign_key: "user_id",
      dependent: :destroy,
    )

    # Metadata belonging to this user
    has_many(
      child_class: Metadata,
      collection_name: "metadata_and_versions",
      foreign_key: "parent_id",
      dependent: :destroy
    )

    has_many(
      child_class: ApiKey,
      collection_name: "api_tokens",
      foreign_key: "user_id",
      dependent: :destroy
    )

    # Validation
    ###############################################################################################

    validates :authority_id, presence: true
    validates :email, presence: true

    validate ->(this : User) {
      this.validation_error(:email, "is an invalid email") unless this.email.valid?
      if lang = this.preferred_language
        # match ISO 639-x codes - 2 and 3 letters
        # the country code is optional and not validated as i8n libs will fallback to the base language
        this.validation_error(:preferred_language, "is an invalid preferred language") unless lang =~ /^[a-zA-Z]{2}[a-zA-Z]?(-[a-zA-Z]+)?$/
      end
    }

    # Ensure email is unique under the authority scope
    #
    ensure_unique :email_digest, scope: [:authority_id, :email_digest] do |authority_id, email_digest|
      {authority_id, email_digest}
    end

    ensure_unique :login_name, scope: [:authority_id]
    ensure_unique :staff_id, scope: [:authority_id]

    # Callbacks
    ###############################################################################################

    before_destroy :ensure_admin_remains
    before_destroy :cleanup_auth_tokens
    before_save :build_name
    before_save :write_email_fields

    private getter admin_destroy_lock : ::PgORM::PgAdvisoryLock do
      ::PgORM::PgAdvisoryLock.new("admin_destroy_lock")
    end

    # :inherit:
    def destroy
      return super unless self.sys_admin
      # Locking to protect against concurrent deletes
      admin_destroy_lock.synchronize { super }
    end

    # Prevent the system from entering a state with no admin
    protected def ensure_admin_remains
      return unless self.sys_admin

      if User.where({sys_admin: true}).count == 1
        raise Model::Error.new("At least one admin must remain")
      end
    end

    # Deletes auth tokens for the `User`
    protected def cleanup_auth_tokens
      user_id = self.id

      begin
        ::PgORM::Database.exec_sql("delete from \"oauth_access_grants\" where resource_owner_id = $1", user_id)
      rescue error
        Log.warn(exception: error) { "failed to remove User<#{user_id}> auth grants" }
      end

      begin
        ::PgORM::Database.exec_sql("delete from \"oauth_access_tokens\" where resource_owner_id = $1", user_id)
      rescue error
        Log.warn(exception: error) { "failed to remove User<#{user_id}> auth token" }
      end
    end

    protected def build_name
      self.name = "#{self.first_name} #{self.last_name}" if self.first_name.presence
    end

    # Sets email_digest to allow user look up without leaking emails
    protected def write_email_fields
      self.email_digest = email.digest
    end

    # Queries
    ###############################################################################################

    def by_authority_id(auth_id : String)
      User.where(auth_id: auth_id)
    end

    def self.find_by_email(authority_id : String, email : PlaceOS::Model::Email | String)
      find_by_emails(authority_id, [email]).first?
    end

    def self.find_by_emails(authority_id : String, emails : Enumerable(String) | Enumerable(Email))
      return [] of self if emails.empty?

      digests = emails.map do |email|
        email = PlaceOS::Model::Email.new(email) if email.is_a?(String)
        email.digest
      end

      User.where(email_digest: digests, authority_id: authority_id)
    end

    def self.find_by_login_name(login_name : String)
      User.where(login_name: login_name).first?
    end

    def self.find_by_login_name(authority_id : String, login_name : String)
      User.where({login_name: login_name, authority_id: authority_id}).first?
    end

    def self.find_by_staff_id(staff_id : String)
      User.where(staff_id: staff_id).first?
    end

    def self.find_by_staff_id(authority_id : String, staff_id : String)
      User.where(staff_id: staff_id, authority_id: authority_id).first?
    end

    def self.find_sys_admins
      User.where(sys_admin: true)
    end

    # Access Control
    ###############################################################################################

    def is_admin?
      sys_admin
    end

    def is_support?
      support
    end

    def to_jwt_permission : UserJWT::Permissions
      is_admin? ? UserJWT::Permissions::Admin : (is_support? ? UserJWT::Permissions::Support : UserJWT::Permissions::User)
    end

    # NOTE: required due to use of `JSON.mapping` macro by `active-model`
    macro finished
      # Ensure the `PlaceOS::Model::User`'s `PlaceOS::Model::Authority` doesn't change
      #
      def assign_attributes_from_json(json)
        saved_authority = self.authority_id
        previous_def(json)
        self.authority_id = saved_authority
        self
      end
    end

    # Sets sensitve admin attributes restricted from mass assigment.
    # Handles.. {% for field in AdminAttributes.instance_vars %}
    # - {{ field.name }}
    # {% end %}
    def assign_admin_attributes_from_json(json)
      admin_attributes = AdminAttributes.from_json(json)
      admin_attributes.apply(self)
    end

    # :nodoc:
    struct AdminAttributes
      include JSON::Serializable

      getter sys_admin : Bool?
      getter support : Bool?
      getter login_name : String?
      getter staff_id : String?
      getter card_number : String?
      getter groups : Array(String)?

      def apply(user : Model::User)
        set_if_present(sys_admin, user)
        set_if_present(support, user)
        set_if_present(login_name, user)
        set_if_present(staff_id, user)
        set_if_present(card_number, user)
        set_if_present(groups, user)
        user
      end

      private macro set_if_present(field, model)
        unless (%field = {{ field }}).nil?
          {{ model.id }}.{{ field.id }} = %field
        end
      end
    end

    # Serialisation
    ###############################################################################################

    PUBLIC_DATA = [
      :email_digest, :email, :nickname, :name, :first_name, :last_name, :groups,
      :country, :building, :image, :created_at, :authority_id, :deleted,
      :department, :preferred_language, :staff_id, :phone, :work_preferences,
      :work_overrides, :login_count, :last_login, :photo_upload_id, :locatable,
    ]

    {% begin %}
    ADMIN_DATA = {{
                   PUBLIC_DATA + [
                     :sys_admin, :support, :misc, :login_name, :card_number, :ui_theme,
                   ]
                 }}
    {% end %}

    # Public visible fields
    define_to_json :public, only: PUBLIC_DATA, methods: :id
    define_to_json :public_metadata, only: PUBLIC_DATA, methods: [:id, :associated_metadata]

    # Groups only
    define_to_json :group, only: :groups, methods: :id

    # Admin visible fields
    define_to_json :admin, only: ADMIN_DATA, methods: :id
    define_to_json :admin_metadata, only: ADMIN_DATA, methods: [:id, :associated_metadata]

    def associated_metadata
      Model::Metadata.build_metadata(self)
    end

    # Password Encryption
    ###############################################################################################

    alias Password = Crypto::Bcrypt::Password

    before_save do
      # No password prevents people logging in using the account locally
      if pass = @password
        if pass.empty?
          @password_digest = nil
        else
          digest = Password.create(pass)
          self.password_digest = digest.to_s
        end
      end
      @password = nil
    end

    @[JSON::Field(ignore: true)]
    @[YAML::Field(ignore: true)]
    @pass_compare : Password? = nil

    def password : Password
      @pass_compare ||= Password.new(self.password_digest)
    end

    def password=(new_password : String) : String
      @pass_compare = digest = Password.create(new_password)
      self.password_digest = digest.to_s
      new_password
    end
  end
end

require "./authority"
