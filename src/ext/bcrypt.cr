require "crypto/bcrypt/password"
require "json"
require "yaml"

class Crypto::Bcrypt::Password
  def to_json(builder) : Nil
    build.string(digest)
  end

  def to_yaml(yaml : YAML::Nodes::Builder) : Nil
    yaml.scalar(digest)
  end

  def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
    unless node.is_a?(YAML::Nodes::Scalar)
      node.raise "Expected scalar, not #{node.kind}"
    end

    self.new(node.value)
  end

  def self.from_json(pull : JSON::PullParser)
    self.new(pull.read_string)
  end
end
