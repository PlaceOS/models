require "active-model"
require "json"
require "log"
require "neuroplastic"
require "pg-orm"

require "../utilities/encryption"
require "../utilities/validation"
require "../utilities/id_generator"
require "./associations"
require "./timestamps"
require "./scope"

module PlaceOS::Model
  # Base class for all Engine models
  abstract class ModelBase < ::PgORM::Base
    include Neuroplastic

    macro inherited
      macro finished
        default_primary_key id : String?
      end

      Log = ::Log.for(self)
    end

    before_create { self.id = Utilities::IdGenerator.next(self) unless self.id? }
    before_save { self.id = Utilities::IdGenerator.next(self) unless self.id? }
    include Model::Associations
  end

  # Base class for all models which have auto-generated bigint as pk
  # and doesn't require string based auto generated pk
  abstract class ModelWithAutoKey < ::PgORM::Base
    include Neuroplastic

    macro inherited
      macro finished
        default_primary_key id : Int64?
        include PlaceOS::Model::Timestamps
      end

      Log = ::Log.for(self)
      include Model::Associations
      include Model::Scope

      # :nodoc:
      def self.build_clause(vals, start = 1)
        String.build do |sb|
          vals.each_with_index do |_, idx|
            sb << ", " unless idx == 0
            sb << '$' << idx + start
          end
        end
      end
    end
  end

  # Validation for embedded objects in Engine models
  abstract class SubModel < ActiveModel::Model
    include ActiveModel::Validation

    macro inherited
      Log = ::Log.for(self)
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
          arr << T.from_json(pull.read_raw)
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
  module DBHashConverter(K, V)
    def self.from_rs(rs : ::DB::ResultSet)
      vals = JSON::Any.new(rs.read(JSON::PullParser)).to_json
      Hash(K, V).from_json(vals)
    end

    def self.from_json(pull : JSON::PullParser)
      hash = Hash(K, V).new
      pull.read_object do |key, _key_location|
        hash[key] = V.from_json(pull.read_raw)
      end
      hash
    end

    def self.to_json(value : Hash(K, V) | Nil)
      String.build do |sb|
        value.to_json(sb)
      end
    end

    def self.to_json(value : Hash(K, V) | Nil, builder)
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
      val.to_s
    end

    def self.to_json(val : T | Nil, builder)
      val.try &.to_json(builder)
    end

    def self.to_rs(val : T | Nil)
      val.try &.value
    end
  end

  # :nodoc:
  module PGEnumConverter(T)
    def self.from_rs(rs : ::DB::ResultSet)
      T.parse(rs.read(String))
    end

    def self.from_json(pull : JSON::PullParser) : T
      T.parse?(pull.read_string) || pull.raise "Unknown enum #{T} value: #{pull.string_value}"
    end

    def self.to_json(val : T | Nil)
      val.to_s.upcase
    end

    def self.to_json(val : T | Nil, builder)
      val.try &.to_json(builder)
    end
  end
end

# :nodoc:
module Time::EpochConverter
  def self.from_rs(rs : DB::ResultSet)
    rs.read(Time)
  end
end

module Time::EpochConverterOptional
  def self.from_rs(rs : DB::ResultSet)
    rs.read(Time?)
  end

  def self.from_json(value : JSON::PullParser) : Time?
    str = value.read_raw
    return nil unless str
    if (val = str.to_i?)
      Time.unix(val)
    else
      begin
        Time.from_json(str)
      rescue Time::Format::Error
        fmt = "%FT%T"
        fmt += ".%6N" if str.index('.')
        Time.parse_utc(str.strip('"'), fmt)
      end
    end
  end

  def self.to_json(value : Time?, json : JSON::Builder) : Nil
    if val = value
      json.number(val.to_unix)
    else
      json.null
    end
  end
end
