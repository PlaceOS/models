require "./base/model"

module PlaceOS::Model
  struct Email
    getter address : String
    forward_missing_to address

    def initialize(address : String)
      @address = address.strip.downcase
    end

    def initialize(json : JSON::PullParser)
      @address = json.read_string.strip
    end

    def self.from_json(pull)
      new pull
    end

    def to_s(io)
      io << @address
    end

    def valid?
      address.is_email?
    end

    def digest
      Digest::MD5.hexdigest(@address.downcase)
    end

    # for proper documentation, otherwise this will hinted as an object.
    def self.json_schema(_openapi : Bool? = nil)
      {type: "string", format: "email"}
    end
  end

  # :nodoc:
  module EmailConverter
    def self.from_rs(rs : ::DB::ResultSet)
      Email.new(rs.read(String?) || "")
    end

    def self.from_json(value : JSON::PullParser)
      Email.from_json(value)
    end

    def self.to_json(value : Email, json : JSON::Builder)
      json.string(value.to_s)
    end

    def self.to_json(value : Email?)
      value.try &.to_s
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Email
      node.raise "Expected scalar, not #{node.class}" unless node.is_a?(YAML::Nodes::Scalar)
      Email.new(node.value.to_s)
    end

    def self.to_yaml(value : JSON::Any, yaml : YAML::Nodes::Builder)
      yaml.scalar(value.to_s)
    end
  end
end
