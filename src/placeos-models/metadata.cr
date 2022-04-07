require "json"
require "openapi-generator/serializable"
require "rethinkdb-orm"
require "rethinkdb"
require "time"
require "pars"

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
    attribute details : JSON::Any
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
      # `parent_id` presence is already enforced
      return if metadata.parent_id.nil?

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

    abstract struct Query
      abstract def apply(query_builder)

      macro finished
        enum Type
          # ameba:disable Style/VerboseBlock
          {% for type in Query.all_subclasses.reject { |type| type.abstract? } %}
            {{ type.stringify.split("::").last.id }}
          {% end %}
        end

        # Parsing
        #########################################################################

        protected def self.parse?(param_key : String, param_value : String?)
          parsed_key = key_parser.parse(param_key)
          return if parsed_key.is_a?(Pars::ParseError)
          type, key = parsed_key[:type], parsed_key[:key]

          if param_value && param_value.presence
            value = param_string_parser.parse(param_value)
            return if value.is_a?(Pars::ParseError)
          end

          {key: key, value: value, type: type}
        end

        protected class_getter key_parser : Pars::Parser(NamedTuple(type: Type, key: String?)) do
          type_word_parser = ((Pars::Parse.char('_') | Pars::Parse.letter) * (1..)).map &.join
          Pars::Parse.do({
            type <= type_word_parser.map { |word| Type.parse(word) },
            key <= key_bracket_parser,
            Pars::Parse.const({
              type: type,
              key:  key,
            }),
          })
        end
      end

      # Restrict the values/keys to a safe set of characters
      protected class_getter param_string_parser : Pars::Parser(String) do
        param_safe_char_parser = Pars::Parse.alphanumeric | Pars::Parse.one_char_of({'-', '.', '_', '~'})
        (param_safe_char_parser * (1..)).map &.join
      end

      # There may or may not be a key in the query
      protected class_getter key_bracket_parser : Pars::Parser(String?) do
        bracketed_key = Pars::Parse.char('[') >> param_string_parser << Pars::Parse.char(']')
        (bracketed_key * (0..1)).map &.first?
      end

      # Constructor
      #########################################################################

      # ameba:disable Metrics/CyclomaticComplexity
      def self.from_param?(param_key : String, param_value : String?)
        return unless parsed = parse?(param_key, param_value)
        type, key, value = parsed[:type], parsed[:key], parsed[:value]

        case type
        in .association?
          if key.nil? && value && (association = Association::Type.parse?(value))
            Association.new(association)
          end
        in .key_missing?
          KeyMissing.new(key) if key && value.nil?
        in .equals?
          Equals.new(key, value) if key && value
        in .starts_with?
          StartsWith.new(key, value) if key && value
        end
      end

      struct Association < Query
        getter value : Association::Type

        protected def initialize(@value)
        end

        def apply(query_builder)
          query_builder.filter do |document|
            document["parent_id"].match("^#{value.id_prefix}")
          end
        end

        enum Type
          System
          Zone
          User

          def id_prefix
            case self
            in .system? then Model::ControlSystem.table_name
            in .zone?   then Model::Zone.table_name
            in .user?   then Model::User.table_name
            end
          end
        end
      end

      abstract struct WithKey < Query
        getter key : String

        protected getter key_parts : Array(String) do
          key.split('.')
        end

        protected def initialize(@key)
        end

        protected def lookup_key(document, expected = true)
          # Ensure final value is not an object and all intermediates are objects
          lookups = key_parts.reduce([document["details"]]) do |objects, part|
            objects.push(objects.last[part])
          end

          # Intermediate lookups MUST be objects
          object_lookups = lookups[..-2].reduce(RethinkDB.expr(true)) do |objects_so_far, lookup|
            objects_so_far.and(lookup.type_of.eq("OBJECT"))
          end

          value_lookup = lookups.last
          query = object_lookups
          query = query.and(value_lookup.type_of.ne("OBJECT")) if expected
          query.and(yield value_lookup)
        end
      end

      struct KeyMissing < Query::WithKey
        protected def initialize(@key)
        end

        def apply(query_builder)
          query_builder.filter do |document|
            lookup_key(document, expected: false) do |_lookup|
              RethinkDB.expr(true)
            end.not
          end
        end
      end

      struct Equals < Query::WithKey
        getter key : String
        getter value : String

        protected def initialize(@key, @value)
        end

        def apply(query_builder)
          query_builder.filter do |document|
            lookup_key(document) do |lookup|
              lookup.eq(value)
            end
          end
        end
      end

      struct StartsWith < Query::WithKey
        getter key : String
        getter value : String

        protected def initialize(@key, @value)
        end

        def apply(query_builder)
          query_builder.filter do |document|
            lookup_key(document) do |lookup|
              lookup.match("^#{value}")
            end
          end
        end
      end
    end

    def self.query(query_conditions : Array(Query))
      master_metadata_query do |query_builder|
        query_conditions.reduce(query_builder) do |q, condition|
          condition.apply(q)
        end
      end
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

      @[JSON::Field(converter: Time::EpochConverter)]
      @updated_at : Time
      @[JSON::Field(converter: Time::EpochConverter)]
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

    def assign_from_interface(user : Model::UserJWT, interface : Interface)
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
      self.details = interface.details
      self
    end

    def self.build_metadata(parent, name : String? = nil) : Hash(String, Interface)
      for(parent, name).each_with_object({} of String => Interface) do |data, results|
        results[data.name] = data.interface
      end
    end

    def self.build_history(parent, name : String? = nil, offset : Int32 = 0, limit : Int32 = 10)
      for(parent, name).each_with_object({} of String => Array(Interface)) do |data, results|
        results[data.name] = data.history(offset, limit).map(&.interface)
      end
    end
  end
end
