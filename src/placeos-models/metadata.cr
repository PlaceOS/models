require "json"
require "json-merge-patch/ext"
require "openapi-generator/serializable"
require "pars"

require "pg-orm"
require "time"

require "./utilities/last_modified"
require "./utilities/versions"

require "./base/model"
require "./control_system"
require "./zone"

module PlaceOS::Model
  class Metadata < ModelBase
    include PlaceOS::Model::Timestamps
    include Utilities::LastModified
    include Utilities::Versions

    table :metadata

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""
    attribute details : JSON::Any
    attribute editors : Set(String) = ->{ Set(String).new }

    attribute parent_id : String, es_type: "keyword"
    attribute schema_id : String?, es_type: "keyword"

    # Association
    ###############################################################################################

    # Models that `Metadata` is attached to

    belongs_to Zone, foreign_key: "parent_id", association_name: "zone"
    belongs_to ControlSystem, foreign_key: "parent_id", association_name: "control_system"
    belongs_to User, foreign_key: "parent_id", association_name: "user"

    def parent : User | ControlSystem | Zone | Nil
      return if (p_id = parent_id).nil?
      case p_id
      when .starts_with?(Model::ControlSystem.table_name) then control_system
      when .starts_with?(Model::Zone.table_name)          then zone
      when .starts_with?(Model::User.table_name)          then user
      end
    end

    # Schema for validating `details` object
    belongs_to JsonSchema, foreign_key: "schema_id", association_name: "schema"

    # Serialisation
    ###############################################################################################

    # Groups only
    define_to_json :parent, methods: :parent

    # Validation
    ###############################################################################################

    validates :details, presence: true
    validates :name, presence: true
    validates :parent_id, presence: true

    validate ->Metadata.validate_parent_exists(Metadata)
    validate ->Metadata.validate_unique_name(Metadata)

    def self.validate_parent_exists(metadata : Metadata)
      # Skip validation if `Metadata` has been created
      return unless metadata.new_record?
      # `parent_id` presence is already enforced
      return if metadata.parent_id.nil?

      table_name = metadata.parent_id.as(String).partition('-').first

      found = PgORM::Database.connection do |db|
        db.scalar(<<-SQL, metadata.parent_id).as(Int64) > 0
          select count(*) from "#{table_name}" where id = $1
        SQL
      end
      metadata.validation_error(:parent_id, "must reference an existing model") unless found
    end

    def self.validate_unique_name(metadata : Metadata)
      return if (name = metadata.name.strip.presence).nil?
      # Ignore validating versions uniqueness
      return if metadata.is_version?

      # Set to stripped value
      metadata.name = name

      # TODO: Optimise uniqueness validation query in RethinkORM
      # `is_empty` should make this a faster query.
      model = Metadata.for(metadata.parent_id.not_nil!, name).first?

      if model && model.id != metadata.id
        metadata.validation_error(:name, "must be unique beneath 'parent_id'")
      end
    end

    # Queries
    ###############################################################################################

    def self.for(parent : String | Zone | ControlSystem | User, name : String? = nil)
      parent_id = case parent
                  in String
                    parent
                  in Zone, ControlSystem, User
                    parent.id.as(String)
                  end

      master_metadata_query do |q|
        q = q.where(parent_id: parent_id)
        q = q.where(name: name) if name && !name.empty?
        q
      end
    end

    # Generate a version upon save of a master Metadata
    #
    protected def create_version(version : self) : self
      version.details = details.clone
      version
    end

    # Serialisation
    ###############################################################################################

    record(
      Interface,
      name : String,
      description : String,
      details : JSON::Any,
      parent_id : String?,
      schema_id : String? = nil,
      editors : Set(String) = Set(String).new,
      modified_by_id : String? = nil,
      updated_at : Time = Time.utc,
      created_at : Time = Time.utc,
    ) do
      include JSON::Serializable
      extend OpenAPI::Generator::Serializable

      @[JSON::Field(converter: Time::EpochConverter, type: "integer", format: "Int64")]
      @updated_at : Time
      @[JSON::Field(converter: Time::EpochConverter, type: "integer", format: "Int64")]
      @created_at : Time
    end

    def self.interface(model : Metadata)
      {% begin %}
      Interface.new(
        {% for instance_variable in Model::Metadata::Interface.instance_vars %}
          {{ instance_variable.name }}: model.{{ instance_variable.name }},
        {% end %}
      )
      {% end %}
    end

    def interface
      self.class.interface(self)
    end

    def self.from_interface(interface : Interface)
      new.tap do |model|
        {% begin %}
          {% for instance_variable in Model::Metadata::Interface.instance_vars.reject { |var| {:updated_at, :created_at, :modified_by_id}.includes?(var.name.symbolize) } %}
            if %value{instance_variable} = interface.{{instance_variable.name}}
              model.{{instance_variable.name}} = %value{instance_variable}
            end
          {% end %}
        {% end %}
      end
    end

    # Determine if a user has edit access to the Metadata
    # - Support+ `User`s can edit `Metadata`
    # - `User`s can edit their own `Metadata`
    # - `User`'s with roles in the `Metadata`'s `editors` can edit
    def user_can_update?(user : Model::UserJWT)
      self.class.user_can_create?(self.parent_id, user) ||
        !(self.editors & Set.new(user.user.roles)).empty?
    end

    # Determine if a user has create access to the Metadata
    # - Support+ `User`s can edit `Metadata`
    # - `User`s can edit their own `Metadata`
    def self.user_can_create?(parent_id : String?, user : Model::UserJWT)
      user.is_support? ||
        user.is_admin? ||
        parent_id == user.id
    end

    def assign_from_interface(user : Model::UserJWT, interface : Interface, merge_details : Bool = false)
      # Only support+ users can edit the editors list
      if (updated_editors = interface.editors) && user.is_support?
        self.editors = updated_editors
      end

      # Only support+ users can edit the schema
      if (updated_schema_id = interface.schema_id) && user.is_support?
        self.schema_id = updated_schema_id
      end

      # Update existing Metadata
      self.description = interface.description

      # Merge or replace
      self.details = merge_details ? self.details.merge(interface.details) : interface.details
      self
    end

    def self.build_metadata(parent, name : String? = nil) : Hash(String, Interface)
      for(parent, name).each_with_object({} of String => Interface) do |data, results|
        results[data.name] = data.interface
      end
    end

    def self.build_history(parent, name : String? = nil, offset : Int32 = 0, limit : Int32 = 10)
      raise ArgumentError.new("Neither `offset` nor `limit` may be negative") if offset < 0 || limit < 0
      for(parent, name).each_with_object({} of String => Array(Interface)) do |data, results|
        results[data.name] = data.history(offset, limit).map(&.interface)
      end
    end
  end
end
