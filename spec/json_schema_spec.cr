require "./helper"

module PlaceOS::Model
  describe JsonSchema do
    test_round_trip(JsonSchema)

    it "saves a json schema" do
      schema = Generator.json_schema.save!

      schema_find = JsonSchema.find!(schema.id.as(String))
      schema_find.id.should eq schema.id
      schema_find.name.should eq schema.name
      schema_find.schema.should eq schema.schema

      schema.destroy
    end

    it "is associated with metadata" do
      zone = Generator.zone.save!
      schema = Generator.json_schema.save!
      meta = Generator.metadata(parent: zone.id.as(String))
      meta.schema = schema
      meta.save!

      meta_find = Metadata.find!(meta.id.as(String))
      meta_find.schema!.id.should eq schema.id

      zone.destroy
      schema.destroy
    end
  end
end
