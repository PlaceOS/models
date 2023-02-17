require "active-model"
require "json"
require "log"
require "neuroplastic"
require "pg-orm"

require "openapi-generator"
require "openapi-generator/serializable"
require "openapi-generator/serializable/adapters/active-model"

require "../utilities/encryption"
require "../utilities/validation"
require "../utilities/id_generator"
require "./associations"
require "./timestamps"

module PlaceOS::Model
  # Base class for all Engine models
  abstract class ModelBase < PgORM::Base
    include Neuroplastic

    macro inherited
      macro finished
        default_primary_key id : String?, autogenerated: true
      end

      Log = ::Log.for(self)
      include OpenAPI::Generator::Serializable::Adapters::ActiveModel
      extend OpenAPI::Generator::Serializable
    end

    before_create { self.id = Utilities::IdGenerator.next(self) unless self.id? }
    before_save { self.id = Utilities::IdGenerator.next(self) unless self.id? }
    include Model::Associations
  end

  # Validation for embedded objects in Engine models
  abstract class SubModel < ActiveModel::Model
    include ActiveModel::Validation

    macro inherited
      Log = ::Log.for(self)
      include OpenAPI::Generator::Serializable::Adapters::ActiveModel
      extend OpenAPI::Generator::Serializable
    end

    # RethinkDB library serializes through JSON::Any
    def to_reql
      JSON.parse(self.to_json)
    end

    # Propagate submodel validation errors to parent's
    protected def collect_errors(collection : Symbol, models)
      errors = models.compact_map do |m|
        m.errors unless m.valid?
      end

      errors.flatten.each do |e|
        validation_error(field: collection, message: e.to_s)
      end
    end
  end

  # :nodoc:
  module DBArrConverter(T)
    def self.from_rs(rs : ::DB::ResultSet)
      vals = JSON::Any.new(rs.read(JSON::PullParser)).to_json
      Array(T).from_json(vals)
    end

    def self.from_json(pull : JSON::PullParser)
      arr = Array(T).new
      pull.read_array do
        if T <= UserJWT::Scope
          arr << T.new(pull)
        else
          arr << T.from_json(pull.read_string)
        end
      end
      arr
    end

    def self.to_json(value : Array(T) | Nil)
      String.build do |sb|
        value.to_json(sb)
      end
    end

    def self.to_json(value : Array(T) | Nil, builder)
      value.to_json(builder)
    end
  end

  # :nodoc:
  module EnumConverter(T)
    def self.from_rs(rs : ::DB::ResultSet)
      val = rs.read(Int32)
      T.from_value(val)
    end

    def self.from_json(pull : JSON::PullParser) : T
      str = pull.read_raw
      if (val = str.to_i?)
        T.from_value?(val) || pull.raise "Unknown enum #{T} value: #{str}"
      else
        T.parse?(str.strip('"')) || pull.raise "Uknown enum #{T} value: #{str}"
      end
    end

    def self.to_json(val : T | Nil)
      val.value.to_s
    end

    def self.to_json(val : T | Nil, builder)
      val.try &.value.to_json(builder)
    end
  end
end

# :nodoc:
module Time::EpochConverter
  def self.from_rs(rs : DB::ResultSet)
    rs.read(Time?)
  end
end
