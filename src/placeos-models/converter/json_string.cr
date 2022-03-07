require "json"
require "yaml"

# :nodoc:
# Used to prevent overwrite the object merges of RethinkDB
module JSON::Any::StringConverter
  def self.from_json(value : JSON::PullParser) : JSON::Any
    JSON.parse(value.read_string)
  end

  def self.to_json(value : JSON::Any, json : JSON::Builder)
    json.string(value.to_json)
  end

  def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : JSON::Any
    node.raise "Expected scalar, not #{node.class}" unless node.is_a?(YAML::Nodes::Scalar)
    JSON.parse(node.value.to_s)
  end

  def self.to_yaml(value : JSON::Any, yaml : YAML::Nodes::Builder)
    yaml.scalar(value.to_json)
  end
end
