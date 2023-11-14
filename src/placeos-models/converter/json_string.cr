require "json"
require "yaml"

# :nodoc:
module JSON::Any::StringConverter
  def self.from_json(value : JSON::PullParser) : JSON::Any
    v = value.read_raw
    if v.is_a?(String)
      if v.strip('"') == "{}"
        JSON::Any.new({} of String => JSON::Any)
      else
        JSON.parse(v.to_s)
      end
    else
      JSON::Any.new(v)
    end
  end

  def self.to_json(value : JSON::Any, json : JSON::Builder)
    if h = value.as_h?
      JSON::Any.new(h.to_json).to_json(json)
    else
      value.to_json(json)
    end
  end

  def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : JSON::Any
    node.raise "Expected scalar, not #{node.class}" unless node.is_a?(YAML::Nodes::Scalar)
    JSON.parse(node.value.to_s)
  end

  def self.to_yaml(value : JSON::Any, yaml : YAML::Nodes::Builder)
    yaml.scalar(value.to_json)
  end

  def self.from_rs(rs : ::DB::ResultSet)
    JSON::Any.new(rs.read(JSON::PullParser))
  end

  def self.to_json(value : JSON::Any?)
    value.try &.to_json
  end
end

module Enum::ValueConverter(T)
  def self.from_rs(rs : ::DB::ResultSet)
    val = rs.read(Int32?) || 0
    T.from_value(val)
  end

  def self.to_json(val : T | Nil)
    return nil if val.nil?
    previous_def
  end

  def self.to_json(val : T | Nil, builder)
    val.try &.to_json(builder)
  end

  # support either integers or strings when pulling
  def self.from_json(pull : JSON::PullParser) : T
    value = pull.read?(Int64) || pull.read_string_or_null || 0_i64
    case value
    in Int64
      T.from_value?(value) || pull.raise "Unknown enum #{T} value: #{value}"
    in String
      begin
        T.parse(value)
      rescue error
        pull.raise "Unknown enum #{T} value: #{value} (#{error.message})"
      end
    end
  end
end

module OptionalRecordConverter(T)
  def self.from_rs(rs : ::DB::ResultSet)
    val = rs.read(JSON::PullParser?)
    if v = val
      T.from_json(JSON::Any.new(v).to_json)
    end
  end

  def self.from_json(pull : JSON::PullParser)
    T.from_json(pull.read_string)
  end

  def self.to_json(val : T | Nil)
    val.try &.to_json
  end

  def self.to_json(val : T | Nil, builder)
    val.try &.to_json(builder)
  end
end
