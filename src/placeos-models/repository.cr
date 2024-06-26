require "time"

require "./base/model"
require "./utilities/encryption"

module PlaceOS::Model
  # Pins engine's driver sources to a specific repository state.
  # Enables external driver management from a VCS.
  class Repository < ModelBase
    include PlaceOS::Model::Timestamps

    table :repo

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""

    # `folder_name` may only contain valid path characters
    attribute folder_name : String

    attribute uri : String
    attribute commit_hash : String = "HEAD"
    attribute branch : String = "master"
    attribute deployed_commit_hash : String? = nil, mass_assignment: false

    # Whether the repository is pinned to a release asset
    attribute release : Bool = false

    # Authentication

    attribute username : String?
    attribute password : String?

    enum Type
      Driver
      Interface

      def to_reql
        JSON::Any.new(to_s.downcase)
      end
    end

    attribute repo_type : Type = Type::Driver, converter: PlaceOS::Model::EnumConverter(PlaceOS::Model::Repository::Type), es_type: "text"

    # Error Indicators
    attribute has_runtime_error : Bool = false, mass_assignment: false
    attribute error_message : String? = nil, mass_assignment: false

    # Association
    ###############################################################################################

    has_many(
      child_class: Driver,
      collection_name: "drivers",
      foreign_key: "repository_id",
      dependent: :destroy
    )

    # Validation
    ###############################################################################################

    validates :name, presence: true
    validates :folder_name, presence: true, format: {with: /^[a-zA-Z0-9_+\-\(\)\.]*$/}
    validates :repo_type, presence: true
    validates :uri, presence: true
    validates :commit_hash, presence: true

    validate ->(this : Model::Repository) {
      this.validation_error(:uri, "is an invalid URI") unless Validation.valid_uri?(this.uri)
    }

    ensure_unique :folder_name, scope: [:repo_type, :folder_name] do |repo_type, folder_name|
      {repo_type, folder_name.strip.downcase}
    end

    # Callbacks
    ###############################################################################################

    before_create :set_id
    before_save :encrypt!

    # Generate ID before document is created
    protected def set_id
      self.new_record = true
      @id = Utilities::IdGenerator.next(self)
    end

    # Encrypt sensitive fields
    def encrypt!
      self.username = username.presence

      self.password = encrypt_password
      self
    end

    # Encryption
    ###############################################################################################

    {% for field in {:password} %}
      {% for action in {:encrypt, :decrypt} %}
        # {{ action }} the `{{ field }}` attribute, using `PlaceOS::Encryption`
        def {{ action.id }}_{{ field.id }}
          %temp = {{ field.id }}
          return if %temp.nil? || %temp.presence.nil?
          Encryption.{{ action.id }}(%temp, id.as(String), Encryption::Level::NeverDisplay)
        end
      {% end %}
    {% end %}

    # Cloning Management
    ###############################################################################################

    def pull!
      commit_hash_will_change!
      self.deployed_commit_hash = nil
      save!
    end
  end
end
