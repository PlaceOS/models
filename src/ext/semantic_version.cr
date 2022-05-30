require "json"
require "semantic_version"

struct SemanticVersion
  def to_json(json)
    json.string self.to_s
  end

  def self.new(pull : JSON::PullParser)
    parse pull.read_string
  end
end
