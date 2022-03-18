require "rethinkdb-orm"
require "time"
require "json"

require "./converter/json_string"
require "./utilities/last_modified"
require "./utilities/versions"

require "./base/model"
require "./control_system"
require "./zone"

module PlaceOS::Model
  class Metadata < ModelBase
    include RethinkORM::Timestamps
    include Utilities::LastModified
    include Utilities::Versions

    table :metadata

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""
    attribute details : JSON::Any, converter: JSON::Any::StringConverter
    attribute editors : Set(String) = ->{ Set(String).new }

    attribute parent_id : String, es_type: "keyword"
    attribute schema_id : String?, es_type: "keyword"

    # Association
    ###############################################################################################

    secondary_index :parent_id

    # Models that `Metadata` is attached to
    belongs_to Zone, foreign_key: "parent_id", association_name: "zone"
    belongs_to ControlSystem, foreign_key: "parent_id", association_name: "control_system"
    belongs_to User, foreign_key: "parent_id", association_name: "user"

    # Schema for validating `details` object
    belongs_to JsonSchema, foreign_key: "schema_id", association_name: "schema"

    # Validation
    ###############################################################################################

    validates :details, presence: true
    validates :name, presence: true
    validates :parent_id, presence: true

    validate ->Metadata.validate_parent_exists(Metadata)
    validate ->Metadata.validate_unique_name(Metadata)

    def self.validate_parent_exists(metadata : Metadata)
      # Skip validation if `Metadata` has been created
      return unless metadata.id.nil?

      table_name = metadata.parent_id.as(String).partition('-').first
      if RethinkORM::Connection.raw(&.table(table_name).get(metadata.parent_id)).raw.nil?
        metadata.validation_error(:parent_id, "must reference an existing model")
      end
    end

    def self.validate_unique_name(metadata : Metadata)
      return if (name = metadata.name.strip.presence).nil?
      # Ignore validating versions uniqueness
      return if metadata.is_version?

      # Set to stripped value
      metadata.name = name

      # TODO: Optimise uniqueness validation query in RethinkORM
      # `is_empty` should make this a faster query.
      model = Metadata
        .master_metadata_query(&.filter({parent_id: metadata.parent_id, name: name}))
        .first?

      if model && model.id != metadata.id
        metadata.validation_error(:name, "must be unique beneath 'parent_id'")
      end
    end

    # Queries
    ###############################################################################################

    enum Association
      Zone
      ControlSystem
      User

      def prefix
        case self
        in Zone          then Zone.table_name
        in ControlSystem then ControlSystem.table_name
        in User          then User.table_name
        end
      end
    end

    def self.search(
      association : Association
    )
    end

    def self.for(parent : String | Zone | ControlSystem | User, name : String? = nil)
      parent_id = case parent
                  in String
                    parent
                  in Zone, ControlSystem, User
                    parent.id.as(String)
                  end

      master_metadata_query do |q|
        q = q.get_all(parent_id, index: :parent_id)
        q = q.filter({name: name}) if name && !name.empty?
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

    record Interface, name : String, description : String, details : JSON::Any, editors : Set(String)?, parent_id : String? {
      include JSON::Serializable
    }

    def self.interface(model : Metadata)
      Interface.new(
        name: model.name,
        description: model.description,
        details: model.details,
        parent_id: model.parent_id,
        editors: model.editors,
      )
    end

    def self.build_metadata(parent, name : String? = nil) : Hash(String, Interface)
      for(parent, name).each_with_object({} of String => Interface) do |data, results|
        results[data.name] = self.interface(data)
      end
    end
  end
end
