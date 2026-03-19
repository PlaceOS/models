require "./helper"

module PlaceOS::Model
  describe Playlist::Item do
    Spec.before_each do
      Playlist::Item.clear
      Playlist.clear
      ControlSystem.clear
    end

    it "create a playlist item" do
      upload = Generator.upload.save!
      media_id = upload.id.as(String)

      example_json = %({
          "created_at": 1723440666,
          "updated_at": 1723440666,
          "name": "Screenshot 2024-08-12 at 12.51.43 PM.png",
          "animation": "cut",
          "media_type": "image",
          "orientation": "landscape",
          "media_uri": "https://s3-ap-southeast-2.amazonaws.com/17234316461372523291.png",
          "media_id": "#{media_id}",
          "thumbnail_id": "#{media_id}",
          "valid_from": 1723440666,
          "valid_until": 17234406666
      })

      object = Playlist::Item.from_json example_json
      item = Playlist::Item.new
      item.clear_changes_information
      item.assign_attributes_from_json(example_json)

      authority = Authority.find_by_domain("localhost").as(Authority)
      item.authority_id = authority.id

      item.save.should eq true
    end

    it "cleans up playlists when an item is deleted" do
      revision = Generator.revision

      item = Generator.item
      item.save!
      item1_id = item.id.as(String)
      item2 = Generator.item
      item2.save!
      item2_id = item2.id.as(String)

      revision.items = [item1_id, item2_id]
      revision.save!
      revision = Playlist::Revision.find(revision.id.as(String))
      revision.items.should eq [item1_id, item2_id]

      playlist = revision.playlist.not_nil!
      updated = playlist.updated_at
      sleep 1.second
      item.destroy

      revision = Playlist::Revision.find(revision.id.as(String))
      revision.items.should eq [item2_id]
      playlist = revision.playlist.not_nil!

      updated.should_not eq playlist.updated_at
    end

    it "creates a plugin item" do
      plugin = Generator.signage_plugin.save!
      item = Generator.plugin_item(plugin: plugin)
      item.save!

      found = Playlist::Item.find(item.id.as(String))
      found.media_type.should eq Playlist::Item::MediaType::Plugin
      found.plugin_id.should eq plugin.id
    end

    it "requires a plugin_id for plugin items" do
      item = Generator.item
      item.media_type = Playlist::Item::MediaType::Plugin
      item.media_uri = nil
      item.plugin_id = nil
      item.save.should eq false
      item.errors.any? { |e| e.field == :plugin_id }.should eq true
    end

    it "validates plugin_params keys exist in plugin params properties" do
      plugin = Generator.signage_plugin(
        params: {
          "type"       => JSON::Any.new("object"),
          "properties" => JSON::Any.new({
            "play_at_period" => JSON::Any.new({"type" => JSON::Any.new("integer")} of String => JSON::Any),
          } of String => JSON::Any),
        },
      ).save!

      item = Generator.plugin_item(
        plugin: plugin,
        plugin_params: {"bad_key" => JSON::Any.new(5_i64)},
      )
      item.save.should eq false
      item.errors.any? { |e| e.field == :plugin_params }.should eq true
    end

    it "validates required params are satisfied by defaults merged with plugin_params" do
      plugin = Generator.signage_plugin(
        params: {
          "type"       => JSON::Any.new("object"),
          "properties" => JSON::Any.new({
            "play_at_period" => JSON::Any.new({"type" => JSON::Any.new("integer")} of String => JSON::Any),
            "color"          => JSON::Any.new({"type" => JSON::Any.new("string")} of String => JSON::Any),
          } of String => JSON::Any),
          "required" => JSON::Any.new([JSON::Any.new("play_at_period"), JSON::Any.new("color")]),
        },
        defaults: {"play_at_period" => JSON::Any.new(10_i64)},
      ).save!

      # missing "color" which is required and has no default
      item = Generator.plugin_item(
        plugin: plugin,
        plugin_params: {} of String => JSON::Any,
      )
      item.save.should eq false
      item.errors.any? { |e| e.field == :plugin_params && e.message.to_s.includes?("color") }.should eq true
    end

    it "allows plugin_params when defaults cover required params" do
      plugin = Generator.signage_plugin(
        params: {
          "type"       => JSON::Any.new("object"),
          "properties" => JSON::Any.new({
            "play_at_period" => JSON::Any.new({"type" => JSON::Any.new("integer")} of String => JSON::Any),
            "color"          => JSON::Any.new({"type" => JSON::Any.new("string")} of String => JSON::Any),
          } of String => JSON::Any),
          "required" => JSON::Any.new([JSON::Any.new("play_at_period"), JSON::Any.new("color")]),
        },
        defaults: {"play_at_period" => JSON::Any.new(10_i64)},
      ).save!

      # "color" provided in plugin_params, "play_at_period" covered by defaults
      item = Generator.plugin_item(
        plugin: plugin,
        plugin_params: {"color" => JSON::Any.new("red")},
      )
      item.save.should eq true
    end

    it "updates playlists when an item is modified" do
      revision = Generator.revision

      item = Generator.item
      item.save!
      item1_id = item.id.as(String)
      item2 = Generator.item
      item2.save!
      item2_id = item2.id.as(String)

      revision.items = [item1_id, item2_id]
      revision.save!
      revision = Playlist::Revision.find(revision.id.as(String))
      revision.items.should eq [item1_id, item2_id]

      playlist = revision.playlist.not_nil!
      updated = playlist.updated_at
      sleep 1.second
      item.animation = Playlist::Animation::SlideTop
      item.save!

      revision = Playlist::Revision.find(revision.id.as(String))
      playlist = revision.playlist.not_nil!

      updated.should_not eq playlist.updated_at
    end
  end
end
