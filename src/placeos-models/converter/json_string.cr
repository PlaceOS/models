require "json"
require "yaml"

# :nodoc:
module JSON::Any::StringConverter
  def self.from_json(value : JSON::PullParser) : JSON::Any
    JSON::Any.new(value)
  end

  def self.to_json(value : JSON::Any, json : JSON::Builder)
    value.to_json(json)
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
    T.from_value(rs.read(Int32))
  end
end
