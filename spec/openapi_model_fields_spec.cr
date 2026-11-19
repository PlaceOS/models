require "json-schema"
require "spec"
require "../src/placeos-models"

module PlaceOS::Model
  describe "Model OpenAPI field types" do
    it "describes serialized scope strings in JWTs and API keys" do
      scopes = [UserJWT::Scope::PUBLIC, UserJWT::Scope.new("custom", UserJWT::Scope::Access::Read)]
      JSON.parse(scopes.to_json).should eq JSON.parse(%(["public","custom.Read"]))

      refs = JSON::Schema::Definitions.new("#/components/schemas/")
      jwt_scope = JSON.parse(UserJWT.json_schema(refs: refs).to_json)["properties"]["scope"]
      key_scopes = JSON.parse(ApiKey.json_schema(true, refs).to_json)["properties"]["scopes"]
      string_schema = JSON.parse(%({"type":"string"}))
      jwt_scope["items"].should eq string_schema
      key_scopes["items"].should eq string_schema
    end

    it "describes metadata entries for both User metadata views" do
      refs = JSON::Schema::Definitions.new("#/components/schemas/")
      {User::AdminMetadataResponse, User::PublicMetadataResponse}.each do |response|
        properties = JSON.parse(response.json_schema(true, refs).to_json)["properties"]
        metadata = properties["associated_metadata"]
        metadata["additionalProperties"]["$ref"].should eq "#/components/schemas/PlaceOS.Model.Metadata.Interface"
      end
    end

    it "serializes Driver schema objects as JSON strings and preserves other JSON values" do
      driver = Driver.new
      driver.json_schema = JSON.parse(%({"type":"object"}))
      JSON.parse(driver.to_json)["json_schema"].as_s.should eq %({"type":"object"})

      {"[]", "true", "7", %("schema"), "null"}.each do |value|
        driver.json_schema = JSON.parse(value)
        JSON.parse(driver.to_json)["json_schema"].should eq JSON.parse(value)
      end
    end

    it "serializes Guest event metadata as an object" do
      metadata = EventMetadata.new(event_id: "event-1")
      metadata.render_linked_bookings = false
      guest = Guest.new(email: "visitor@example.com")
      guest.event_metadata = metadata.to_json

      JSON.parse(guest.to_json)["event_metadata"].should eq JSON.parse(metadata.to_json)
      guest.event_metadata = nil
      JSON.parse(guest.to_json)["event_metadata"]?.should be_nil
    end
  end
end
