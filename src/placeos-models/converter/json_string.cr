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
end
