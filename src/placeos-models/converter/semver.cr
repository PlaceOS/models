require "json"
require "yaml"
require "semantic_version"

# :nodoc:
# NOTE: Previously used in `PlaceOS::Model::Driver`
struct SemanticVersion
  # Allows serialization to rethinkDB query language
  def to_reql
    JSON::Any.new(self.to_s)
  end
end

# :nodoc:
# Serialization for SemanticVersion fields of models
module SemanticVersion::Converter
  def self.from_json(value : JSON::PullParser) : SemanticVersion
    SemanticVersion.parse(value.read_string)
  end

  def self.to_json(value : SemanticVersion, json : JSON::Builder)
    json.string(value.to_s)
  end

  def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : SemanticVersion
    node.raise "Expected scalar, not #{node.class}" unless node.is_a?(YAML::Nodes::Scalar)
    SemanticVersion.parse(node.value.to_s)
  end

  def self.to_yaml(value : SemanticVersion, yaml : YAML::Nodes::Builder)
    yaml.scalar(value.to_s)
  end
end
