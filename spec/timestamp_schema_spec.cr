require "json-schema"
require "spec"
require "../src/placeos-models"

module PlaceOS::Model
  describe "Epoch timestamp schemas" do
    it "describes the Edge heartbeat using its serialized integer type" do
      time = Time.unix(1_700_000_000)
      edge = Edge.new
      edge.last_seen = time
      JSON.parse(edge.to_json)["last_seen"].as_i64.should eq time.to_unix

      refs = JSON::Schema::Definitions.new("#/components/schemas/")
      properties = JSON.parse(Edge.json_schema(true, refs).to_json)["properties"]
      properties["last_seen"].should eq JSON.parse(%({"type":"integer","format":"Int64","nullable":true}))
    end

    it "describes the Shortener validity timestamps using their serialized integer type" do
      start = Time.unix(1_700_000_000)
      finish = start + 1.hour
      shortener = Shortener.new(valid_from: start, valid_until: finish)
      json = JSON.parse(shortener.to_json)
      json["valid_from"].as_i64.should eq start.to_unix
      json["valid_until"].as_i64.should eq finish.to_unix

      refs = JSON::Schema::Definitions.new("#/components/schemas/")
      properties = JSON.parse(Shortener.json_schema(true, refs).to_json)["properties"]
      epoch = JSON.parse(%({"type":"integer","format":"Int64","nullable":true}))
      properties["valid_from"].should eq epoch
      properties["valid_until"].should eq epoch
    end
  end
end
