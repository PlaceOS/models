require "json"
require "time"
require "db"

class Time::Location
  def to_json(json : JSON::Builder) : Nil
    json.string(self.to_s)
  end
end

module Time::Location::Converter
  def self.from_json(value : JSON::PullParser) : Time::Location
    Time::Location.load(value.read_string)
  end

  def self.to_json(value : Time::Location, json : JSON::Builder)
    json.string(value.to_s)
  end

  def self.to_json(value : Time::Location?)
    value.try &.to_s
  end

  def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Time::Location
    unless node.is_a?(YAML::Nodes::Scalar)
      node.raise "Expected scalar, not #{node.class}"
    end
    Time::Location.load(node.value.to_s)
  end

  def self.to_yaml(value : Time::Location, yaml : YAML::Nodes::Builder)
    yaml.scalar(value.to_s)
  end

  def self.from_rs(rs : ::DB::ResultSet)
    val = rs.read(String?)
    val ? Time::Location.load(val.not_nil!) : nil
  end
end
