require "time"

# Creates created_at and updated_at attributes.
# - `updated_at` is set through the `before_update` callback
# - `created_at` is set through the `before_update` callback
#
module PlaceOS::Model::Timestamps
  macro included
    attribute created_at : Time = ->{ Time.utc }, converter: PlaceOS::Model::Timestamps::EpochConverter, type: "integer", format: "Int64"
    attribute updated_at : Time = ->{ Time.utc }, converter: PlaceOS::Model::Timestamps::EpochConverter, type: "integer", format: "Int64"

    before_create do
      self.created_at = self.updated_at = Time.utc
    end

    before_update do
      self.updated_at = Time.utc
    end
  end
end

# :nodoc:
module PlaceOS::Model::Timestamps::EpochConverter
  def self.from_rs(rs : DB::ResultSet) : Time
    rs.read(Time)
  end

  def self.from_json(value : JSON::PullParser) : Time
    str = value.read_raw
    if (val = str.to_i?)
      Time.unix(val)
    else
      Time.from_json(str)
    end
  end

  def self.to_json(value : Time, json : JSON::Builder) : Nil
    json.number(value.to_unix)
  end

  def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Time
    unless node.is_a?(YAML::Nodes::Scalar)
      node.raise "Expected scalar, not #{node.kind}"
    end

    Time.unix(node.value.to_i)
  end
end

module PlaceOS::Model::Timestamps::EpochMillisConverter
  def self.from_rs(rs : DB::ResultSet) : Time
    rs.read(Time)
  end

  def self.from_json(value : JSON::PullParser) : Time
    str = value.read_raw
    if (val = str.to_i?)
      Time.unix_ms(val)
    else
      Time.from_json(str)
    end
  end

  def self.to_json(value : Time, json : JSON::Builder) : Nil
    json.number(value.to_unix_ms)
  end

  def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Time
    unless node.is_a?(YAML::Nodes::Scalar)
      node.raise "Expected scalar, not #{node.kind}"
    end

    Time.unix_ms(node.value.to_i64)
  end
end
