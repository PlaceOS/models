require "./helper"

module PlaceOS::Model
  describe SignagePlugin do
    Spec.before_each do
      SignagePlugin.clear
    end

    test_round_trip(SignagePlugin)

    it "creates a signage plugin" do
      plugin = Generator.signage_plugin
      plugin.save!

      found = SignagePlugin.find(plugin.id.as(String))
      found.name.should eq plugin.name
      found.enabled.should eq true
    end

    it "requires a name" do
      plugin = Generator.signage_plugin(name: "")
      plugin.save.should eq false
      plugin.errors.first.field.should eq :name
    end

    it "validates defaults keys exist in params properties" do
      plugin = Generator.signage_plugin(
        params: {
          "type"       => JSON::Any.new("object"),
          "properties" => JSON::Any.new({
            "play_at_period" => JSON::Any.new({"type" => JSON::Any.new("integer")} of String => JSON::Any),
          } of String => JSON::Any),
        },
        defaults: {
          "play_at_period" => JSON::Any.new(10_i64),
        },
      )
      plugin.save.should eq true
    end

    it "rejects defaults with keys not in params properties" do
      plugin = Generator.signage_plugin(
        params: {
          "type"       => JSON::Any.new("object"),
          "properties" => JSON::Any.new({
            "play_at_period" => JSON::Any.new({"type" => JSON::Any.new("integer")} of String => JSON::Any),
          } of String => JSON::Any),
        },
        defaults: {
          "nonexistent_key" => JSON::Any.new("value"),
        },
      )
      plugin.save.should eq false
      plugin.errors.first.field.should eq :defaults
    end

    it "allows empty defaults" do
      plugin = Generator.signage_plugin(
        defaults: {} of String => JSON::Any,
      )
      plugin.save.should eq true
    end
  end
end
